-- TODO: Inventar-Schema für Tag 3
--
-- Legt hier euer Datenmodell für die Inventar-App an.
-- Vorschlag für die Reihenfolge:
--   1. Stammdaten-Tabellen (department, person, device_type, location)
--   2. device
--   3. assignment
--
-- Ergänzt anschließend kleine Seed-Daten, damit ihr eure Flows testen könnt.

create table if not exists department (
    department_id serial primary key,
    abteilung  text not null unique
);

create table if not exists device_type (
    device_type_id serial primary key,
    type_name text not null
);

create table if not exists location_info (
    location_id serial primary key,
    standort text not null unique
);

create table if not exists person (
    person_id serial primary key,
    mitarbeiter_id text not null unique,
    first_name  text not null,
    last_name   text not null,
    department_id int not null references department(department_id) on delete cascade,
    location_id int not null references location_info(location_id) on delete cascade
);

create table if not exists devices (
    device_id serial primary key,
    serial_number text not null unique,
    device_type int not null references device_type(device_type_id) on delete cascade,
    device_model text not null,
    buy_date date not null,
    net_price decimal not null,
    device_location int not null references location_info(location_id) on delete cascade
);

create table if not exists assignment (
    assignment_id serial primary key,
    person_id int not null references person(person_id) on delete cascade,
    device_id int not null references devices(device_id) on delete cascade,
    issue_date date not null,
    return_date date
);

insert into department(abteilung) values
    ('IT'),
    ('Produktion'),
    ('Vertrieb'),
    ('Marketing');

insert into device_type(type_name) values
    ('Laptop'),
    ('Monitor'),
    ('Tablet');

insert into location_info(standort) values
    ('Berlin'),
    ('Hamburg'),
    ('München');

insert into person (mitarbeiter_id, first_name, last_name, department_id, location_id)
select p.mitarbeiter_id, p.first_name, p.last_name, d.department_id, l.location_id
from (values
    ('1001', 'Aleksandr', 'Weinhage', 'IT', 'Berlin'),
    ('1002', 'Eleni', 'Hauffer', 'IT', 'Berlin'),
    ('1003', 'Paul', 'Dobes-Stiffel', 'Produktion', 'Hamburg')
) as p(mitarbeiter_id, first_name, last_name, abteilung, standort)
join department d on d.abteilung = p.abteilung
join location_info l on l.standort = p.standort
on conflict do nothing;

insert into devices (serial_number, device_type, device_model, buy_date, net_price, device_location)
select d.serial_number, dt.device_type_id, d.device_model, d.buy_date, d.net_price, l.location_id
from (values
    ('G0012', 'Tablet', 'Galaxy Tab', date '2022-06-01', 968.43, 'Hamburg'),
    ('G0021', 'Monitor', 'Samsung Curved', date '2023-09-21', 1134.16, 'München'),
    ('G0024', 'Monitor', 'Dell UltraSharp', date '2022-03-01', 750.91, 'Berlin')
) as d(serial_number, type_name, device_model, buy_date, net_price, standort)
join device_type dt on d.type_name = dt.type_name
join location_info l on l.standort = d.standort
on conflict do nothing;

insert into assignment (person_id, device_id, issue_date, return_date)
select p.person_id, d.device_id, a.issue_date, a.return_date
from (values
    ('1001', 'G0012', date '2024-05-09', NULL),
    ('1002', 'G0021', date '2024-06-29', date '2025-06-29'),
    ('1003', 'G0024', date '2024-05-09', date '2024-06-09')
) as a(mitarbeiter_id, serial_number, issue_date, return_date)
join devices d on d.serial_number = a.serial_number
join person p on p.mitarbeiter_id = a.mitarbeiter_id
on conflict do nothing;