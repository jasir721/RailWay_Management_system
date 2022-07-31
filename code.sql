--fare
create or replace function compute_fare(class varchar,category varchar,src_order integer,dest_order integer)
returns integer
as $$
declare fare integer;
begin
    fare:=500;
    if(class = 'AC') then fare:=fare*2;
    end if;
    if(category = 'Tatkal') then fare:=fare*1.5;
    elsif(category = 'Ladies') then fare:=fare*0.7;
    elsif(category = 'Senior') then fare:=fare*0.5;
    end if;
    fare:=fare*(dest_order-src_order);
    return fare;
end;
$$ language plpgsql;

--Assign seat if its available
create or replace function assign_seat(t_no integer,dod date,p_class varchar)
returns integer as $$
declare seat integer;
begin
 seat:=0;
 if exists (select seat_no from availability,schedule where s_no = schedule_no
 and  schedule.train_no = t_no and schedule.date_of_departure = dod and 
 available = true and class = p_class ) then
 begin
    select seat_no from availability,schedule 
    into seat where s_no = schedule_no 
    and  schedule.train_no = t_no and schedule.date_of_departure = dod and 
    available = true and class = p_class 
    order by seat_no limit 1; 
end;
end if;
return seat;
end;
$$language plpgsql;

--book
create or replace procedure book(uid integer,t_no integer,dod date)
as $$
begin
insert into booking(booking_time,booked_by,train_no,date_of_departure) values(LOCALTIMESTAMP(0),uid,t_no,dod);
create or replace view curr_booking as select * from booking order by booking_time desc limit 1;
end;
$$ language plpgsql;


--ticket booking
create or replace procedure book_ticket(f_name varchar,l_name varchar,gender varchar,age integer,p_class varchar,pnr integer,category varchar)
as $$
declare p_id integer;
declare seat_no integer;
declare t_no integer;
declare dod date;
begin
insert into passengers(first_name,last_name,gender,age) values(f_name,l_name,gender,age);
select max(passenger_id) from passengers into p_id;
select train_no from booking into t_no where pnr_number = pnr;
select date_of_departure from booking into dod where pnr_number = pnr;
select * from assign_seat(t_no,dod,p_class) into seat_no;
raise notice '%', seat_no;
if seat_no != 0 then 
    insert into ticket values(p_id,p_class,compute_fare(p_class,category),seat_no,'Confirmed',pnr, category);
else 
    insert into ticket values(p_id,p_class,compute_fare(p_class,category),seat_no,'Waiting List',pnr, category);  
end if; 
end;
$$ language plpgsql;

--Trains View 
create or replace view trains_view as 
select train_name, src, dest, arrival_time, departure_time, date_of_departure, date_of_arrival
from train, schedule where train.train_no = schedule.train_no

--trainlist given src and dest
create or replace function trainlist(sc varchar, dst varchar)
returns table (
Source_station varchar,
Destination_station varchar,
Train_name varchar,
Train_number integer,
Departure_time time,
arrival_time time,
date_of_departure date
)
as $$
begin
	return query
		select r1.station_name, r2.station_name, train.train_name, train.train_no, 
		train.departure_time, train.arrival_time, schedule.date_of_departure
		from route as r1, route as r2, train, schedule
		where train.train_no = schedule.train_no 
        and r1.station_name = src and r2.station_name=dest 
        and r1.train_no = train.train_no and r2.train_no = train.train_no;
end;
$$ language plpgsql;



--Assign seat
-- Function to return integer seat if any seat available
create or replace function assign_seat(t_no integer,dod date,p_class varchar)
returns integer as $$
declare seat integer;
begin
 seat:=0;
 if exists (select seat_no from availability,schedule where s_no = schedule_no
 and  schedule.train_no = t_no and schedule.date_of_departure = dod and 
 available = true and class = p_class ) then
 begin
    select seat_no from availability,schedule 
    into seat where s_no = schedule_no 
    and  schedule.train_no = t_no and schedule.date_of_departure = dod and 
    available = true and class = p_class 
    order by seat_no limit 1; 
end;
end if;
return seat;
end;
$$language plpgsql;

-- Trigger 
--Marking available seat as false in the table
create or replace procedure set_avail()
returns trigger
as $$
begin
    if new.seat_no != 0 then
    update availability set available = false from schedule,booking 
    where seat_no = new.seat_no and passenger_class = new.class 
    s_no = schedule_no and booking.pnr_number = new.pnr_number and 
    schedule.train_no = booking.train_no and schedule.date_of_departure = booking.date_of_departure;
    end if;
    return new;
end;
$$ language plpgsql;
create or replace trigger avail_seat 
before insert
on ticket
for each row
execute procedure set_avail();

--cancel
create or replace procedure cancel(pnr integer)
as $$
begin
    delete from ticket where pnr_number = pnr;
	delete from booking where pnr_number = pnr;
end;
$$ language plpgsql;
    

create or replace function delete_passenger()
returns trigger
as $$
begin
    delete from passengers where passenger_id = old.passenger_id;
    return old;
end;
$$ language plpgsql;

create or replace trigger delete_entry 
after delete
on ticket
for each row  
execute procedure delete_passenger();

