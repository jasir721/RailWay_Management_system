--Compute fare which depends on the category and class along with the src and dest.
create or replace function compute_fare(class varchar,category varchar,src_order integer,dest_order integer)
returns integer
as $$
declare fare integer;
begin
    fare:=200;
    if(class = 'AC') then fare:=fare*2;
    end if;
    if(category = 'Tatkal') then fare:=fare*1.5;
    else if(category = 'Ladies') then fare:=fare*0.7;
    else if(category = 'Senior') then fare:=fare*0.5;
    end if;
    fare:=fare*(dest_order-src_order);
    return fare;
end;
$$ language plpgsql;

-- Booking done by a particular user for a particular train_no
create or replace procedure book(uid integer,t_no integer,dod date)
as $$
begin
insert into booking(booking_time,booked_by,train_no,date_of_departure) values(LOCALTIMESTAMP(0),uid,t_no,dod);
create or replace view curr_booking as select * from booking order by booking_time desc limit 1;
end;
$$ language plpgsql;

-- Procedure for booking a ticket for a passenger with given pnr number
create or replace procedure book_ticket(f_name varchar,l_name varchar,gender varchar,age integer,p_class varchar,pnr integer,category varchar,src varchar,dest varchar)
as $$
    declare p_id integer;
    declare seat_no integer;
    declare t_no integer;
    declare dod date;
    declare dest_order integer;
    declare src_order integer;
begin
    insert into passengers(first_name,last_name,gender,age) values(f_name,l_name,gender,age);
    select max(passenger_id) from passengers into p_id;
    select train_no from booking into t_no where pnr_number = pnr;
    select date_of_departure from booking into dod where pnr_number = pnr;
    select "order" from route into src_order where train_no = t_no and station_name = src;
    select "order" from route into dest_order where train_no = t_no and station_name = dest;
    select * from assign_seat(t_no,dod,p_class,src_order,dest_order) into seat_no;
    raise notice '%', seat_no;
    if (seat_no != 0) then 
        insert into ticket values(p_id,p_class,compute_fare(p_class,category,src_order,dest_order),seat_no,'Confirmed',pnr,category,src,dest);
    else 
        insert into ticket values(p_id,p_class,compute_fare(p_class,category,src_order,dest_order),seat_no,'Waiting List',pnr,category,src,dest);  
    end if; 
end;
$$ language plpgsql;

-- Function set_avail() set if any seat is available for given constraints
-- and src->dest then that seat is assigned and marked as unavailable
create or replace function set_avail()
returns trigger
as $$
declare src_order integer;
declare dest_order integer;
begin
    select "order" from route,booking into src_order where booking.pnr_number = new.pnr_number and
    route.train_no=booking.train_no and station_name = new.src;
    select "order" from route,booking into dest_order where booking.pnr_number = new.pnr_number and
    route.train_no=booking.train_no and station_name = new.dest;

    if new.seat_no != 0 then
    update availability set available_arr[src_order:dest_order-1]=array_fill(false,ARRAY[dest_order-src_order]) from schedule,booking 
    where seat_no = new.seat_no and class = new.passenger_class and
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

