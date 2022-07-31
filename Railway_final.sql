-- Functions

-- Assign Seat
declare seat integer;
begin
    seat:=0;
    if exists (select seat_no from availability,schedule where s_no = schedule_no
    and  schedule.train_no = t_no and schedule.date_of_departure = dod and 
    true = all(available_arr[src:dest-1]) and class = p_class ) then
    begin
        select seat_no from availability,schedule 
        into seat where s_no = schedule_no 
        and  schedule.train_no = t_no and schedule.date_of_departure = dod and 
        true = all(available_arr[src:dest-1]) and class = p_class 
        order by seat_no limit 1; 
    end;
    end if;
    return seat;
end;
