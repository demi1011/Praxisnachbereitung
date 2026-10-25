from fastapi import FastAPI, Request, Query
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, RedirectResponse
import os
from .db import get_conn
import paho.mqtt.client as mqtt
from datetime import date

app = FastAPI(title="Inventar Starter", version="0.1.0")
templates = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))

MQTT_HOST = os.getenv("MQTT_HOST", "mqtt")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))

def mqtt_client() -> mqtt.Client:
    c = mqtt.Client()
    c.connect(MQTT_HOST, MQTT_PORT, keepalive=30)
    return c

@app.get("/health")
async def health():
    db_state = "ok"
    mqtt_state = "ok"
    try:
        with get_conn() as conn, conn.cursor() as cur:
            cur.execute("select 1")
            cur.fetchone()
    except Exception as ex:
        db_state = f"error:{type(ex).__name__}"

    try:
        c = mqtt_client()
        c.disconnect()
    except Exception as ex:
        mqtt_state = f"degraded:{type(ex).__name__}"

    return {"status": "ok" if db_state == "ok" else "degraded", "db": db_state, "mqtt": mqtt_state}

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request, "title": "Inventar Starter"})

@app.get("/inventory", response_class=HTMLResponse)
async def inventory_page(request: Request):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """
                select d.serial_number, dt.type_name, d.device_model
                from devices d
                join device_type dt on d.device_type = dt.device_type_id;
            """
        )
        devices = list(cur.fetchall())
    
    return templates.TemplateResponse(
        "inventory.html",
        {"request": request, "title": "Geräte", "devices": devices}
    )

@app.post("/mqtt/publish")
async def mqtt_publish(topic: str = Query(...), payload: str = Query(...)):
    c = mqtt_client()
    c.publish(topic, payload, qos=0, retain=False)
    c.disconnect()
    return {"ok": True, "topic": topic, "payload": payload}

@app.get("/devices", response_class=HTMLResponse)
async def devices_page(request: Request):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("""
            select * from devices;
        """)

        devices = list(cur.fetchall())

    return templates.TemplateResponse(
        "inventory.html",
        {"request": request, "title": "Geräte", "devices": devices}
    )

@app.post("/devices", response_class=HTMLResponse)
async def update_device(request: Request, serial_number: str, type_name: str, device_model: str, buy_date: date, net_price: float, standort: str):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("""
            insert into devices (serial_number, device_type, device_model, buy_date, net_price, device_location)
            select d.serial_number, dt.device_type_id, d.device_model, d.buy_date, d.net_price, l.location_id
            from (values
                (%s, %s, %s, %s, %s, %s)
            ) as d(serial_number, type_name, device_model, buy_date, net_price, standort)
            join device_type dt on d.type_name = dt.type_name
            join location_info l on l.standort = d.standort;
            """,
            (serial_number, type_name, device_model, buy_date, net_price, standort)
        )

        return RedirectResponse("/devices", status_code=303)