toc.dat                                                                                             0000600 0004000 0002000 00000101127 14630037536 0014450 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        PGDMP   
    #                |         	   Gym final    16.2    16.2 [    ?           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false         @           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false         A           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false         B           1262    18408 	   Gym final    DATABASE        CREATE DATABASE "Gym final" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';
    DROP DATABASE "Gym final";
                postgres    false                     2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                pg_database_owner    false         C           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   pg_database_owner    false    4         �            1255    18499    calculate_membership_price()    FUNCTION       CREATE FUNCTION public.calculate_membership_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    freeze_price INT;
    months_price INT;
BEGIN
    SELECT price_per_month INTO months_price FROM Rates WHERE id_rate = NEW.id_rate;
    SELECT price_per_30_days_of_freezing INTO freeze_price FROM Rates WHERE id_rate = NEW.id_rate;
    
    freeze_price := freeze_price * NEW.freezing/30;
    months_price := months_price * NEW.duaration;
    
    NEW.price := months_price + freeze_price;
    
    RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.calculate_membership_price();
       public          postgres    false    4         �            1255    18734    calculate_training_price()    FUNCTION     4  CREATE FUNCTION public.calculate_training_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    certificate_count INT;
BEGIN
    -- Подсчет количества сертификатов у тренера
    SELECT COUNT(*) INTO certificate_count
    FROM certificates
    WHERE id_employee = NEW.id_employee;

    -- Установка цены за тренировку по формуле 3*(1.2 - (1 / (certificate_count + 1)))
    NEW.price_per_training := 3 * (1.2 - (1.0 / (certificate_count + 1))) * 1000;
    
    RETURN NEW;
END;
$$;
 1   DROP FUNCTION public.calculate_training_price();
       public          postgres    false    4         �            1255    18774 6   check_client_employee_same_gym_and_active_membership()    FUNCTION     u  CREATE FUNCTION public.check_client_employee_same_gym_and_active_membership() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    client_gym_id INT;
    employee_gym_id INT;
    membership_active BOOLEAN;
BEGIN
    -- Получаем id_Gym для клиента и проверяем, что абонемент активен
    SELECT id_Gym, active_inactive = 'да' into client_gym_id, membership_active
    FROM GymMembership
    WHERE id_Client = NEW.id_Client
    LIMIT 1; -- Предполагаем, что клиент зарегистрирован хотя бы в одном зале

    -- Получаем id_Gym для сотрудника
    SELECT id_Gym INTO employee_gym_id
    FROM employees
    WHERE id_employee = NEW.id_employee;

    -- Проверяем, что клиент и сотрудник зарегистрированы в одном и том же зале
    -- и что абонемент клиента активен
    IF client_gym_id IS NULL OR employee_gym_id IS NULL OR client_gym_id <> employee_gym_id OR NOT membership_active THEN
        RAISE EXCEPTION 'Клиент (id_Client = %) и сотрудник (id_employee = %) не зарегистрированы в одном и том же зале или абонемент клиента не активен', NEW.id_Client, NEW.id_employee;
    END IF;

    RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.check_client_employee_same_gym_and_active_membership();
       public          postgres    false    4         �            1255    18772    check_employee_position()    FUNCTION     �  CREATE FUNCTION public.check_employee_position() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    employee_position CHAR(20);
BEGIN
    -- Извлекаем должность сотрудника из таблицы employees
    SELECT position INTO employee_position
    FROM employees
    WHERE id_employee = NEW.id_employee;
    
    -- Проверяем, что должность сотрудника "продавец"
    IF employee_position <> 'Продавец' THEN
        RAISE EXCEPTION 'Сотрудник (id_employee = %) не является продавцом', NEW.id_employee;
    END IF;

    RETURN NEW;
END;
$$;
 0   DROP FUNCTION public.check_employee_position();
       public          postgres    false    4         �            1255    18504    check_schedule_conflict()    FUNCTION     �  CREATE FUNCTION public.check_schedule_conflict() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM schedule
        WHERE id_group = NEW.id_group
        AND day_of_week = NEW.day_of_week
        AND start_time = NEW.start_time
    ) THEN
        RAISE EXCEPTION 'Ошибка при попытке вставить новую запись. Наложение занятий.';
    END IF;
    RETURN NEW;
END;
$$;
 0   DROP FUNCTION public.check_schedule_conflict();
       public          postgres    false    4         �            1255    18762    check_scheduletr_conflicts()    FUNCTION     e  CREATE FUNCTION public.check_scheduletr_conflicts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    conflicting_trainer INT;
    conflicting_client INT;
BEGIN
    -- Проверка на конфликт тренера
    SELECT COUNT(*)
    INTO conflicting_trainer
    FROM scheduletr st
    JOIN individualtr it ON st.id_individualtr = it.id_individualtr
    WHERE it.id_employee = (SELECT it2.id_employee FROM individualtr it2 WHERE it2.id_individualtr = NEW.id_individualtr)
    AND st.start_time = NEW.start_time
    AND st.day_of_week = NEW.day_of_week
    AND st.id <> NEW.id;

    IF conflicting_trainer > 0 THEN
        RAISE EXCEPTION 'Тренер уже занят в это время на другой тренировке';
    END IF;

    -- Проверка на конфликт клиента
    SELECT COUNT(*)
    INTO conflicting_client
    FROM scheduletr st
    JOIN individualtr it ON st.id_individualtr = it.id_individualtr
    WHERE it.id_client = (SELECT it2.id_client FROM individualtr it2 WHERE it2.id_individualtr = NEW.id_individualtr)
    AND st.start_time = NEW.start_time
    AND st.day_of_week = NEW.day_of_week
    AND st.id <> NEW.id;

    IF conflicting_client > 0 THEN
        RAISE EXCEPTION 'Клиент уже занят в это время на другой тренировке';
    END IF;

    RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.check_scheduletr_conflicts();
       public          postgres    false    4         �            1255    18453    set_rate_id()    FUNCTION     n  CREATE FUNCTION public.set_rate_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    selected_rate_id int;
begin
    -- Поиск тарифа, действующего на дату покупки
    select id_rate
    into selected_rate_id
    from Rates
    where new.date_of_purchase between start_date and end_date
    limit 1;

    -- Если тариф найден, устанавливаем id_rate
    if found then
        new.id_rate := selected_rate_id;
    else
        raise exception 'No valid rate found for the purchase date %', new.date_of_purchase;
    end if;

    return new;
end;
$$;
 $   DROP FUNCTION public.set_rate_id();
       public          postgres    false    4         �            1259    18581    certificates    TABLE     �   CREATE TABLE public.certificates (
    id_certificate integer NOT NULL,
    id_employee integer,
    certificate_name character(100)
);
     DROP TABLE public.certificates;
       public         heap    postgres    false    4         �            1259    18414    clients    TABLE     I  CREATE TABLE public.clients (
    id_client integer NOT NULL,
    surname character(20),
    first_name character(20),
    patronymic character(20),
    gender character(10),
    date_of_birth date,
    phone_number character(20),
    CONSTRAINT clients_gender_check CHECK ((gender = ANY (ARRAY['м'::bpchar, 'ж'::bpchar])))
);
    DROP TABLE public.clients;
       public         heap    postgres    false    4         �            1259    18571 	   employees    TABLE     �   CREATE TABLE public.employees (
    id_employee integer NOT NULL,
    id_gym integer,
    surname character(20),
    first_name character(20),
    patronymic character(20),
    date_of_birth date,
    salaty integer,
    "position" character(20)
);
    DROP TABLE public.employees;
       public         heap    postgres    false    4         �            1259    18691    groupclient    TABLE     c   CREATE TABLE public.groupclient (
    id_group integer NOT NULL,
    id_client integer NOT NULL
);
    DROP TABLE public.groupclient;
       public         heap    postgres    false    4         �            1259    18671    groups    TABLE     �   CREATE TABLE public.groups (
    id_group integer NOT NULL,
    id_gym integer,
    id_employee integer,
    training_name character(20)
);
    DROP TABLE public.groups;
       public         heap    postgres    false    4         �            1259    18409    gym    TABLE     �   CREATE TABLE public.gym (
    id_gym integer NOT NULL,
    opening_time time without time zone,
    closing_time time without time zone,
    address character(150),
    phone_number character(20)
);
    DROP TABLE public.gym;
       public         heap    postgres    false    4         �            1259    18456    gymmembership    TABLE     �  CREATE TABLE public.gymmembership (
    id_membership integer NOT NULL,
    id_gym integer,
    id_client integer,
    id_rate integer,
    duaration integer,
    freezing integer,
    price integer,
    date_of_purchase date,
    start_date date,
    active_inactive character(3),
    CONSTRAINT chk_freezing CHECK ((freezing = ANY (ARRAY[0, 30, 60, 90]))),
    CONSTRAINT gymmembership_active_inactive_check CHECK ((active_inactive = ANY (ARRAY['да'::bpchar, 'нет'::bpchar])))
);
 !   DROP TABLE public.gymmembership;
       public         heap    postgres    false    4         �            1259    18455    gymmembership_id_membership_seq    SEQUENCE     �   CREATE SEQUENCE public.gymmembership_id_membership_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.gymmembership_id_membership_seq;
       public          postgres    false    219    4         D           0    0    gymmembership_id_membership_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.gymmembership_id_membership_seq OWNED BY public.gymmembership.id_membership;
          public          postgres    false    218         �            1259    18706    individualtr    TABLE     {   CREATE TABLE public.individualtr (
    id_employee integer,
    id_client integer,
    id_individualtr integer NOT NULL
);
     DROP TABLE public.individualtr;
       public         heap    postgres    false    4         �            1259    18601    products    TABLE     u   CREATE TABLE public.products (
    id_product integer NOT NULL,
    product_name character(20),
    price integer
);
    DROP TABLE public.products;
       public         heap    postgres    false    4         �            1259    18636    productstore    TABLE     {   CREATE TABLE public.productstore (
    id_product integer NOT NULL,
    id_store integer NOT NULL,
    quantity integer
);
     DROP TABLE public.productstore;
       public         heap    postgres    false    4         �            1259    18420    rates    TABLE     �   CREATE TABLE public.rates (
    id_rate integer NOT NULL,
    price_per_month integer,
    price_per_30_days_of_freezing integer,
    start_date date,
    end_date date
);
    DROP TABLE public.rates;
       public         heap    postgres    false    4         �            1259    18721    schedule    TABLE     �  CREATE TABLE public.schedule (
    id_training integer NOT NULL,
    day_of_week character(20),
    id_group integer,
    start_time time without time zone,
    CONSTRAINT schedule_day_of_week_check CHECK ((day_of_week = ANY (ARRAY['Понедельник'::bpchar, 'Вторник'::bpchar, 'Среда'::bpchar, 'Четверг'::bpchar, 'Пятница'::bpchar, 'Суббота'::bpchar, 'Воскресенье'::bpchar])))
);
    DROP TABLE public.schedule;
       public         heap    postgres    false    4         �            1259    18751 
   scheduletr    TABLE     �  CREATE TABLE public.scheduletr (
    id integer NOT NULL,
    id_individualtr integer,
    day_of_week character(20),
    start_time time without time zone,
    CONSTRAINT scheduletr_day_of_week_check CHECK ((day_of_week = ANY (ARRAY['Понедельник'::bpchar, 'Вторник'::bpchar, 'Среда'::bpchar, 'Четверг'::bpchar, 'Пятница'::bpchar, 'Суббота'::bpchar, 'Воскресенье'::bpchar])))
);
    DROP TABLE public.scheduletr;
       public         heap    postgres    false    4         �            1259    18591    store    TABLE     �   CREATE TABLE public.store (
    id_store integer NOT NULL,
    id_gym integer,
    store_name character(26),
    id_employee integer
);
    DROP TABLE public.store;
       public         heap    postgres    false    4         �            1259    18736    trainerrates    TABLE     g   CREATE TABLE public.trainerrates (
    id_employee integer NOT NULL,
    price_per_training integer
);
     DROP TABLE public.trainerrates;
       public         heap    postgres    false    4         �            1259    18666 	   trainings    TABLE     f   CREATE TABLE public.trainings (
    training_name character(20) NOT NULL,
    price_per_tr integer
);
    DROP TABLE public.trainings;
       public         heap    postgres    false    4         ]           2604    18459    gymmembership id_membership    DEFAULT     �   ALTER TABLE ONLY public.gymmembership ALTER COLUMN id_membership SET DEFAULT nextval('public.gymmembership_id_membership_seq'::regclass);
 J   ALTER TABLE public.gymmembership ALTER COLUMN id_membership DROP DEFAULT;
       public          postgres    false    219    218    219         2          0    18581    certificates 
   TABLE DATA           U   COPY public.certificates (id_certificate, id_employee, certificate_name) FROM stdin;
    public          postgres    false    221       4914.dat -          0    18414    clients 
   TABLE DATA           r   COPY public.clients (id_client, surname, first_name, patronymic, gender, date_of_birth, phone_number) FROM stdin;
    public          postgres    false    216       4909.dat 1          0    18571 	   employees 
   TABLE DATA           |   COPY public.employees (id_employee, id_gym, surname, first_name, patronymic, date_of_birth, salaty, "position") FROM stdin;
    public          postgres    false    220       4913.dat 8          0    18691    groupclient 
   TABLE DATA           :   COPY public.groupclient (id_group, id_client) FROM stdin;
    public          postgres    false    227       4920.dat 7          0    18671    groups 
   TABLE DATA           N   COPY public.groups (id_group, id_gym, id_employee, training_name) FROM stdin;
    public          postgres    false    226       4919.dat ,          0    18409    gym 
   TABLE DATA           X   COPY public.gym (id_gym, opening_time, closing_time, address, phone_number) FROM stdin;
    public          postgres    false    215       4908.dat 0          0    18456    gymmembership 
   TABLE DATA           �   COPY public.gymmembership (id_membership, id_gym, id_client, id_rate, duaration, freezing, price, date_of_purchase, start_date, active_inactive) FROM stdin;
    public          postgres    false    219       4912.dat 9          0    18706    individualtr 
   TABLE DATA           O   COPY public.individualtr (id_employee, id_client, id_individualtr) FROM stdin;
    public          postgres    false    228       4921.dat 4          0    18601    products 
   TABLE DATA           C   COPY public.products (id_product, product_name, price) FROM stdin;
    public          postgres    false    223       4916.dat 5          0    18636    productstore 
   TABLE DATA           F   COPY public.productstore (id_product, id_store, quantity) FROM stdin;
    public          postgres    false    224       4917.dat .          0    18420    rates 
   TABLE DATA           n   COPY public.rates (id_rate, price_per_month, price_per_30_days_of_freezing, start_date, end_date) FROM stdin;
    public          postgres    false    217       4910.dat :          0    18721    schedule 
   TABLE DATA           R   COPY public.schedule (id_training, day_of_week, id_group, start_time) FROM stdin;
    public          postgres    false    229       4922.dat <          0    18751 
   scheduletr 
   TABLE DATA           R   COPY public.scheduletr (id, id_individualtr, day_of_week, start_time) FROM stdin;
    public          postgres    false    231       4924.dat 3          0    18591    store 
   TABLE DATA           J   COPY public.store (id_store, id_gym, store_name, id_employee) FROM stdin;
    public          postgres    false    222       4915.dat ;          0    18736    trainerrates 
   TABLE DATA           G   COPY public.trainerrates (id_employee, price_per_training) FROM stdin;
    public          postgres    false    230       4923.dat 6          0    18666 	   trainings 
   TABLE DATA           @   COPY public.trainings (training_name, price_per_tr) FROM stdin;
    public          postgres    false    225       4918.dat E           0    0    gymmembership_id_membership_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.gymmembership_id_membership_seq', 1, false);
          public          postgres    false    218         n           2606    18585    certificates certificates_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id_certificate);
 H   ALTER TABLE ONLY public.certificates DROP CONSTRAINT certificates_pkey;
       public            postgres    false    221         f           2606    18419    clients clients_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id_client);
 >   ALTER TABLE ONLY public.clients DROP CONSTRAINT clients_pkey;
       public            postgres    false    216         l           2606    18575    employees employees_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id_employee);
 B   ALTER TABLE ONLY public.employees DROP CONSTRAINT employees_pkey;
       public            postgres    false    220         z           2606    18695    groupclient groupclient_pkey 
   CONSTRAINT     k   ALTER TABLE ONLY public.groupclient
    ADD CONSTRAINT groupclient_pkey PRIMARY KEY (id_group, id_client);
 F   ALTER TABLE ONLY public.groupclient DROP CONSTRAINT groupclient_pkey;
       public            postgres    false    227    227         x           2606    18675    groups groups_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id_group);
 <   ALTER TABLE ONLY public.groups DROP CONSTRAINT groups_pkey;
       public            postgres    false    226         d           2606    18413    gym gym_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.gym
    ADD CONSTRAINT gym_pkey PRIMARY KEY (id_gym);
 6   ALTER TABLE ONLY public.gym DROP CONSTRAINT gym_pkey;
       public            postgres    false    215         j           2606    18462     gymmembership gymmembership_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT gymmembership_pkey PRIMARY KEY (id_membership);
 J   ALTER TABLE ONLY public.gymmembership DROP CONSTRAINT gymmembership_pkey;
       public            postgres    false    219         |           2606    18750    individualtr individualtr_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.individualtr
    ADD CONSTRAINT individualtr_pkey PRIMARY KEY (id_individualtr);
 H   ALTER TABLE ONLY public.individualtr DROP CONSTRAINT individualtr_pkey;
       public            postgres    false    228         r           2606    18605    products products_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id_product);
 @   ALTER TABLE ONLY public.products DROP CONSTRAINT products_pkey;
       public            postgres    false    223         t           2606    18640    productstore productstore_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.productstore
    ADD CONSTRAINT productstore_pkey PRIMARY KEY (id_product, id_store);
 H   ALTER TABLE ONLY public.productstore DROP CONSTRAINT productstore_pkey;
       public            postgres    false    224    224         h           2606    18424    rates rates_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY public.rates
    ADD CONSTRAINT rates_pkey PRIMARY KEY (id_rate);
 :   ALTER TABLE ONLY public.rates DROP CONSTRAINT rates_pkey;
       public            postgres    false    217         ~           2606    18726    schedule schedule_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (id_training);
 @   ALTER TABLE ONLY public.schedule DROP CONSTRAINT schedule_pkey;
       public            postgres    false    229         �           2606    18756    scheduletr scheduletr_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.scheduletr
    ADD CONSTRAINT scheduletr_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.scheduletr DROP CONSTRAINT scheduletr_pkey;
       public            postgres    false    231         p           2606    18595    store store_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (id_store);
 :   ALTER TABLE ONLY public.store DROP CONSTRAINT store_pkey;
       public            postgres    false    222         �           2606    18740    trainerrates trainerrates_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY public.trainerrates
    ADD CONSTRAINT trainerrates_pkey PRIMARY KEY (id_employee);
 H   ALTER TABLE ONLY public.trainerrates DROP CONSTRAINT trainerrates_pkey;
       public            postgres    false    230         v           2606    18670    trainings trainings_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY public.trainings
    ADD CONSTRAINT trainings_pkey PRIMARY KEY (training_name);
 B   ALTER TABLE ONLY public.trainings DROP CONSTRAINT trainings_pkey;
       public            postgres    false    225         �           2620    18505    gymmembership schedule_conflict    TRIGGER     �   CREATE TRIGGER schedule_conflict AFTER INSERT ON public.gymmembership FOR EACH ROW EXECUTE FUNCTION public.check_schedule_conflict();
 8   DROP TRIGGER schedule_conflict ON public.gymmembership;
       public          postgres    false    219    246         �           2620    18746    trainerrates set_training_price    TRIGGER     �   CREATE TRIGGER set_training_price BEFORE INSERT OR UPDATE ON public.trainerrates FOR EACH ROW EXECUTE FUNCTION public.calculate_training_price();
 8   DROP TRIGGER set_training_price ON public.trainerrates;
       public          postgres    false    247    230         �           2620    18776    individualtr tr2    TRIGGER     �   CREATE TRIGGER tr2 BEFORE INSERT ON public.individualtr FOR EACH ROW EXECUTE FUNCTION public.check_client_employee_same_gym_and_active_membership();
 )   DROP TRIGGER tr2 ON public.individualtr;
       public          postgres    false    228    248         �           2620    18773 !   store trg_check_employee_position    TRIGGER     �   CREATE TRIGGER trg_check_employee_position BEFORE INSERT ON public.store FOR EACH ROW EXECUTE FUNCTION public.check_employee_position();
 :   DROP TRIGGER trg_check_employee_position ON public.store;
       public          postgres    false    244    222         �           2620    18765 )   scheduletr trg_check_scheduletr_conflicts    TRIGGER     �   CREATE TRIGGER trg_check_scheduletr_conflicts BEFORE INSERT OR UPDATE ON public.scheduletr FOR EACH ROW EXECUTE FUNCTION public.check_scheduletr_conflicts();
 B   DROP TRIGGER trg_check_scheduletr_conflicts ON public.scheduletr;
       public          postgres    false    249    231         �           2620    18478    gymmembership trg_set_rate_id    TRIGGER     y   CREATE TRIGGER trg_set_rate_id BEFORE INSERT ON public.gymmembership FOR EACH ROW EXECUTE FUNCTION public.set_rate_id();
 6   DROP TRIGGER trg_set_rate_id ON public.gymmembership;
       public          postgres    false    219    232         �           2620    18503 %   gymmembership update_membership_price    TRIGGER     �   CREATE TRIGGER update_membership_price BEFORE INSERT OR UPDATE OF id_rate, duaration, freezing ON public.gymmembership FOR EACH ROW EXECUTE FUNCTION public.calculate_membership_price();
 >   DROP TRIGGER update_membership_price ON public.gymmembership;
       public          postgres    false    245    219    219    219    219         �           2606    18463    gymmembership f1    FK CONSTRAINT     p   ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT f1 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);
 :   ALTER TABLE ONLY public.gymmembership DROP CONSTRAINT f1;
       public          postgres    false    219    215    4708         �           2606    18681 
   groups f10    FK CONSTRAINT     z   ALTER TABLE ONLY public.groups
    ADD CONSTRAINT f10 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);
 4   ALTER TABLE ONLY public.groups DROP CONSTRAINT f10;
       public          postgres    false    226    4716    220         �           2606    18686 
   groups f11    FK CONSTRAINT     ~   ALTER TABLE ONLY public.groups
    ADD CONSTRAINT f11 FOREIGN KEY (training_name) REFERENCES public.trainings(training_name);
 4   ALTER TABLE ONLY public.groups DROP CONSTRAINT f11;
       public          postgres    false    4726    225    226         �           2606    18696    groupclient f12    FK CONSTRAINT     v   ALTER TABLE ONLY public.groupclient
    ADD CONSTRAINT f12 FOREIGN KEY (id_group) REFERENCES public.groups(id_group);
 9   ALTER TABLE ONLY public.groupclient DROP CONSTRAINT f12;
       public          postgres    false    227    4728    226         �           2606    18701    groupclient f13    FK CONSTRAINT     y   ALTER TABLE ONLY public.groupclient
    ADD CONSTRAINT f13 FOREIGN KEY (id_client) REFERENCES public.clients(id_client);
 9   ALTER TABLE ONLY public.groupclient DROP CONSTRAINT f13;
       public          postgres    false    227    4710    216         �           2606    18711    individualtr f14    FK CONSTRAINT     �   ALTER TABLE ONLY public.individualtr
    ADD CONSTRAINT f14 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);
 :   ALTER TABLE ONLY public.individualtr DROP CONSTRAINT f14;
       public          postgres    false    228    4716    220         �           2606    18716    individualtr f15    FK CONSTRAINT     z   ALTER TABLE ONLY public.individualtr
    ADD CONSTRAINT f15 FOREIGN KEY (id_client) REFERENCES public.clients(id_client);
 :   ALTER TABLE ONLY public.individualtr DROP CONSTRAINT f15;
       public          postgres    false    228    4710    216         �           2606    18727    schedule f16    FK CONSTRAINT     s   ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT f16 FOREIGN KEY (id_group) REFERENCES public.groups(id_group);
 6   ALTER TABLE ONLY public.schedule DROP CONSTRAINT f16;
       public          postgres    false    226    229    4728         �           2606    18741    trainerrates f17    FK CONSTRAINT     �   ALTER TABLE ONLY public.trainerrates
    ADD CONSTRAINT f17 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);
 :   ALTER TABLE ONLY public.trainerrates DROP CONSTRAINT f17;
       public          postgres    false    230    220    4716         �           2606    18757    scheduletr f18    FK CONSTRAINT     �   ALTER TABLE ONLY public.scheduletr
    ADD CONSTRAINT f18 FOREIGN KEY (id_individualtr) REFERENCES public.individualtr(id_individualtr);
 8   ALTER TABLE ONLY public.scheduletr DROP CONSTRAINT f18;
       public          postgres    false    4732    231    228         �           2606    18766 	   store f19    FK CONSTRAINT     y   ALTER TABLE ONLY public.store
    ADD CONSTRAINT f19 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);
 3   ALTER TABLE ONLY public.store DROP CONSTRAINT f19;
       public          postgres    false    220    4716    222         �           2606    18468    gymmembership f2    FK CONSTRAINT     z   ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT f2 FOREIGN KEY (id_client) REFERENCES public.clients(id_client);
 :   ALTER TABLE ONLY public.gymmembership DROP CONSTRAINT f2;
       public          postgres    false    4710    216    219         �           2606    18473    gymmembership f3    FK CONSTRAINT     t   ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT f3 FOREIGN KEY (id_rate) REFERENCES public.rates(id_rate);
 :   ALTER TABLE ONLY public.gymmembership DROP CONSTRAINT f3;
       public          postgres    false    217    4712    219         �           2606    18576    employees f4    FK CONSTRAINT     l   ALTER TABLE ONLY public.employees
    ADD CONSTRAINT f4 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);
 6   ALTER TABLE ONLY public.employees DROP CONSTRAINT f4;
       public          postgres    false    220    4708    215         �           2606    18586    certificates f5    FK CONSTRAINT        ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT f5 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);
 9   ALTER TABLE ONLY public.certificates DROP CONSTRAINT f5;
       public          postgres    false    220    4716    221         �           2606    18596    store f6    FK CONSTRAINT     h   ALTER TABLE ONLY public.store
    ADD CONSTRAINT f6 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);
 2   ALTER TABLE ONLY public.store DROP CONSTRAINT f6;
       public          postgres    false    222    4708    215         �           2606    18641    productstore f7    FK CONSTRAINT     |   ALTER TABLE ONLY public.productstore
    ADD CONSTRAINT f7 FOREIGN KEY (id_product) REFERENCES public.products(id_product);
 9   ALTER TABLE ONLY public.productstore DROP CONSTRAINT f7;
       public          postgres    false    223    224    4722         �           2606    18646    productstore f8    FK CONSTRAINT     u   ALTER TABLE ONLY public.productstore
    ADD CONSTRAINT f8 FOREIGN KEY (id_store) REFERENCES public.store(id_store);
 9   ALTER TABLE ONLY public.productstore DROP CONSTRAINT f8;
       public          postgres    false    4720    222    224         �           2606    18676 	   groups f9    FK CONSTRAINT     i   ALTER TABLE ONLY public.groups
    ADD CONSTRAINT f9 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);
 3   ALTER TABLE ONLY public.groups DROP CONSTRAINT f9;
       public          postgres    false    4708    215    226                                                                                                                                                                                                                                                                                                                                                                                                                                                 4914.dat                                                                                            0000600 0004000 0002000 00000024445 14630037536 0014273 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	2	Сертификат инструктора тренажерного зала                                                            
2	3	Сертификат инструктора тренажерного зала                                                            
3	4	Сертификат инструктора тренажерного зала                                                            
4	5	Сертификат инструктора тренажерного зала                                                            
5	7	Сертификат инструктора тренажерного зала                                                            
6	8	Сертификат инструктора тренажерного зала                                                            
7	9	Сертификат инструктора тренажерного зала                                                            
8	10	Сертификат инструктора тренажерного зала                                                            
9	12	Сертификат инструктора тренажерного зала                                                            
10	13	Сертификат инструктора тренажерного зала                                                            
11	14	Сертификат инструктора тренажерного зала                                                            
12	15	Сертификат инструктора тренажерного зала                                                            
13	17	Сертификат инструктора тренажерного зала                                                            
14	18	Сертификат инструктора тренажерного зала                                                            
15	19	Сертификат инструктора тренажерного зала                                                            
16	20	Сертификат инструктора тренажерного зала                                                            
17	22	Сертификат инструктора тренажерного зала                                                            
18	23	Сертификат инструктора тренажерного зала                                                            
19	24	Сертификат инструктора тренажерного зала                                                            
20	25	Сертификат инструктора тренажерного зала                                                            
21	27	Сертификат инструктора тренажерного зала                                                            
22	28	Сертификат инструктора тренажерного зала                                                            
23	29	Сертификат инструктора тренажерного зала                                                            
24	30	Сертификат инструктора тренажерного зала                                                            
25	32	Сертификат инструктора тренажерного зала                                                            
26	33	Сертификат инструктора тренажерного зала                                                            
27	35	Сертификат инструктора тренажерного зала                                                            
28	36	Сертификат инструктора тренажерного зала                                                            
29	37	Сертификат инструктора тренажерного зала                                                            
30	38	Сертификат инструктора тренажерного зала                                                            
31	39	Сертификат инструктора тренажерного зала                                                            
32	40	Сертификат инструктора тренажерного зала                                                            
33	42	Сертификат инструктора тренажерного зала                                                            
34	43	Сертификат инструктора тренажерного зала                                                            
35	45	Сертификат инструктора тренажерного зала                                                            
36	46	Сертификат инструктора тренажерного зала                                                            
37	47	Сертификат инструктора тренажерного зала                                                            
38	48	Сертификат инструктора тренажерного зала                                                            
39	49	Сертификат инструктора тренажерного зала                                                            
40	2	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
41	5	Наука о спорте и физических упражнениях HNC                                                         
42	10	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
43	13	Сертификат продвинутого уровня по тренерскому спорту и фитнесу                                      
44	15	Наука о спорте и физических упражнениях HNC                                                         
45	19	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
46	23	Наука о спорте и физических упражнениях HNC                                                         
47	27	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
48	30	Наука о спорте и физических упражнениях HNC                                                         
49	33	Сертификат продвинутого уровня по тренерскому спорту и фитнесу                                      
50	35	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
51	38	Наука о спорте и физических упражнениях HNC                                                         
52	40	Сертификат продвинутого уровня по тренерскому спорту и фитнесу                                      
53	42	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
54	45	Наука о спорте и физических упражнениях HNC                                                         
55	48	Сертификат - ТРЕНЕР ПО ПИТАНИЮ Australian Institute Of Fitness                                      
56	35	Сертификат продвинутого уровня по тренерскому спорту и фитнесу                                      
57	46	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
58	47	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
59	48	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
60	49	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
61	2	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
62	5	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
63	10	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
64	13	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
65	30	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
66	33	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
67	35	ОНЛАЙН-ПРОГРАММА МАСТЕР-ТРЕНЕРА Australian Institute Of Fitness                                     
68	63	Программа повышения квалификации менеджеров                                                         
69	64	Программа повышения квалификации менеджеров                                                         
70	65	Программа повышения квалификации менеджеров                                                         
71	66	Программа повышения квалификации менеджеров                                                         
72	67	Программа повышения квалификации менеджеров                                                         
73	68	Программа повышения квалификации менеджеров                                                         
74	69	Программа повышения квалификации менеджеров                                                         
\.


                                                                                                                                                                                                                           4909.dat                                                                                            0000600 0004000 0002000 00000151412 14630037536 0014272 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	Алексей             	Иванович            	Смирнов             	м         	1987-11-03	+79311001110        
2	Екатерина           	Александровна       	Попова              	ж         	1975-07-15	+79311001111        
3	Михаил              	Владимирович        	Кузнецов            	м         	1992-05-28	+79311001112        
4	Анна                	Сергеевна           	Васильева           	ж         	1983-09-19	+79311001113        
5	Иван                	Алексеевич          	Петров              	м         	1968-12-06	+79311001114        
6	Ольга               	Дмитриевна          	Соколова            	ж         	2000-02-24	+79311001115        
7	Дмитрий             	Игоревич            	Михайлов            	м         	1985-08-11	+79311001116        
8	Мария               	Васильевна          	Новикова            	ж         	1973-04-30	+79311001117        
9	Сергей              	Андреевич           	Федоров             	м         	1996-10-22	+79311001118        
10	Татьяна             	Станиславовна       	Морозова            	ж         	1980-06-14	+79311001119        
11	Владимир            	Валентинович        	Волков              	м         	1971-01-09	+79311001110        
12	Наталья             	Петровна            	Алексеева           	ж         	1998-03-17	+79311001111        
13	Александр           	Григорьевич         	Павлов              	м         	1965-07-02	+79311001112        
14	Юлия                	Сергеевна           	Семенова            	ж         	1989-09-25	+79311001113        
15	Павел               	Денисович           	Голубев             	м         	1977-11-08	+79311001114        
16	Елена               	Николаевна          	Виноградова         	ж         	1995-05-01	+79311001115        
17	Андрей              	Владимирович        	Богданов            	м         	1979-12-13	+79311001116        
18	Анастасия           	Михайловна          	Егорова             	ж         	1963-08-29	+79311001117        
19	Константин          	Анатольевич         	Воробьев            	м         	1986-10-05	+79311001118        
20	София               	Ивановна            	Тарасова            	ж         	1974-04-18	+79311001119        
21	Григорий            	Петрович            	Поляков             	м         	1991-06-07	+79311001120        
22	Виктория            	Дмитриевна          	Козлова             	ж         	1969-12-20	+79311001121        
23	Артем               	Степанович          	Жуков               	м         	1988-02-03	+79311001122        
24	Маргарита           	Артемовна           	Комарова            	ж         	1976-07-16	+79311001123        
25	Николай             	Ильич               	Беляев              	м         	1993-05-28	+79311001124        
26	Вера                	Александровна       	Степанова           	ж         	1984-09-11	+79311001125        
27	Владислав           	Ярославович         	Ильин               	м         	1967-12-24	+79311001126        
28	Дарья               	Владимировна        	Романова            	ж         	1999-03-06	+79311001127        
29	Игорь               	Аркадьевич          	Зайцев              	м         	1986-08-19	+79311001128        
30	Валентин            	Даниилович          	Сидоров             	м         	1972-05-01	+79311001129        
31	Ева                 	Викторовна          	Тихонова            	ж         	1997-10-14	+79311001130        
32	Валерий             	Артемьевич          	Соловьев            	м         	1981-04-26	+79311001131        
33	Виолетта            	Геннадьевна         	Карпова             	ж         	1966-11-08	+79311001132        
34	Илья                	Аркадьевич          	Макаров             	м         	1974-07-21	+79311001133        
35	Раиса               	Алексеевна          	Белякова            	ж         	1992-06-02	+79311001134        
36	Геннадий            	Владимирович        	Андреев             	м         	1979-12-15	+79311001135        
37	Альбина             	Николаевна          	Филиппова           	ж         	1964-09-28	+79311001136        
38	Виталий             	Иванович            	Миронов             	м         	1988-10-11	+79311001137        
39	Яна                 	Сергеевна           	Рябова              	ж         	1976-03-23	+79311001138        
40	Даниил              	Владиславович       	Фомин               	м         	1993-08-05	+79311001139        
41	Альфия              	Васильевна          	Орлова              	ж         	1981-01-17	+79311001140        
42	Леонид              	Петрович            	Киселев             	м         	1967-05-30	+79311001141        
43	Зинаида             	Федоровна           	Федотова            	ж         	1994-09-12	+79311001142        
44	Степан              	Александрович       	Тихомиров           	м         	1980-04-25	+79311001143        
45	Эльвира             	Алексеевна          	Галкина             	ж         	1965-06-07	+79311001144        
46	Василиса            	Владимировна        	Савельева           	ж         	1989-12-19	+79311001145        
47	Никита              	Васильевич          	Тарасенко           	м         	1977-03-31	+79311001146        
48	Милана              	Ивановна            	Бирюкова            	ж         	1992-08-13	+79311001147        
49	Егор                	Андреевич           	Жданов              	м         	1970-01-26	+79311001148        
50	Софья               	Павловна            	Богданова           	ж         	1988-05-08	+79311001149        
51	Валерия             	Денисовна           	Белякова            	ж         	1974-09-20	+79311001150        
52	Лев                 	Валерьевич          	Александров         	м         	1999-02-02	+79311001151        
53	Руслана             	Алексеевна          	Суворова            	ж         	1982-07-14	+79311001152        
54	Руслан              	Николаевич          	Панов               	м         	1968-10-27	+79311001153        
55	Агата               	Владимировна        	Чернова             	ж         	1996-04-09	+79311001154        
56	Ильдар              	Иванович            	Шарапов             	м         	1983-08-22	+79311001155        
57	Зарина              	Васильевна          	Дмитриева           	ж         	1971-11-04	+79311001156        
58	Владлен             	Даниилович          	Кондратьев          	м         	1990-06-16	+79311001157        
59	Жанна               	Артемовна           	Горбунова           	ж         	1977-12-29	+79311001158        
60	Вадим               	Семенович           	Артемьев            	м         	1963-07-10	+79311001159        
61	Амелия              	Викторовна          	Гордеева            	ж         	1981-05-23	+79311001160        
62	Денис               	Павлович            	Гусев               	м         	1998-09-05	+79311001161        
63	Амина               	Сергеевна           	Дмитриева           	ж         	1975-03-18	+79311001162        
64	Арсений             	Васильевич          	Королев             	м         	1969-08-30	+79311001163        
65	Агнесса             	Ильинична           	Васильева           	ж         	1993-10-11	+79311001164        
66	Владислава          	Григорьевна         	Молчанова           	ж         	1980-04-22	+79311001165        
67	Мирослав            	Петрович            	Денисов             	м         	1966-08-04	+79311001166        
68	Аделина             	Николаевна          	Журавлева           	ж         	1989-01-17	+79311001167        
69	Виталина            	Александровна       	Соколова            	ж         	1972-05-28	+79311001168        
70	Семен               	Владимирович        	Куликов             	м         	1997-09-10	+79311001169        
71	Лия                 	Игоревна            	Сорокина            	ж         	1984-02-22	+79311001170        
72	Борис               	Дмитриевич          	Мартынов            	м         	1960-07-05	+79311001171        
73	Юлиана              	Валерьевна          	Григорьева          	ж         	1978-03-17	+79311001172        
74	Герман              	Александрович       	Родионов            	м         	1995-08-28	+79311001173        
75	Сусанна             	Анатольевна         	Александрова        	ж         	1981-12-09	+79311001174        
76	Давид               	Аркадьевич          	Корнилов            	м         	1967-06-20	+79311001175        
77	Элина               	Михайловна          	Сазонова            	ж         	1991-11-03	+79311001176        
78	Игнат               	Николаевич          	Горбачев            	м         	1979-04-15	+79311001177        
79	Изабелла            	Дмитриевна          	Гришина             	ж         	1963-09-27	+79311001178        
80	Валентина           	Павловна            	Крылова             	ж         	1988-05-08	+79311001179        
81	Игнатий             	Федорович           	Степанов            	м         	1974-10-19	+79311001180        
82	Артур               	Артурович           	Иванов              	м         	1999-02-01	+79311001181        
83	Алина               	Михайловна          	Козлова             	ж         	1982-07-13	+79311001182        
84	Игнатий             	Владимирович        	Соколов             	м         	1968-11-25	+79311001183        
85	Оксана              	Александровна       	Петрова             	ж         	1996-04-06	+79311001184        
86	Глеб                	Алексеевич          	Федоров             	м         	1983-08-18	+79311001185        
87	Надежда             	Дмитриевна          	Васильева           	ж         	1970-12-30	+79311001186        
88	Илья                	Игоревич            	Кузнецов            	м         	1998-07-10	+79311001187        
89	Лилия               	Анатольевна         	Семенова            	ж         	1984-01-22	+79311001188        
90	Даниил              	Викторович          	Богданов            	м         	1960-06-04	+79311001189        
91	Алиса               	Сергеевна           	Новикова            	ж         	1978-03-16	+79311001190        
92	Денис               	Владимирович        	Григорьев           	м         	1995-08-29	+79311001191        
93	Антонина            	Петровна            	Комарова            	ж         	1981-12-11	+79311001192        
94	Григорий            	Аркадьевич          	Зайцев              	м         	1967-06-23	+79311001193        
95	Екатерина           	Степановна          	Жукова              	ж         	1991-11-05	+79311001194        
96	Станислав           	Александрович       	Королев             	м         	1979-04-17	+79311001195        
97	Марина              	Денисовна           	Морозова            	ж         	1963-09-28	+79311001196        
98	Валерий             	Валентинович        	Тарасов             	м         	1988-05-09	+79311001197        
99	Леонид              	Сергеевич           	Ильин               	м         	1974-10-20	+79311001198        
100	Анна                	Владимировна        	Романова            	ж         	1999-02-01	+79311001199        
101	Антонина            	Валентиновна        	Никитина            	ж         	2005-06-14	+79311001100        
102	Анатолий            	Владимирович        	Козлов              	м         	2004-09-29	+79311001101        
103	Ольга               	Владимировна        	Павлова             	ж         	2006-12-03	+79311001102        
104	Владимир            	Игоревич            	Морозов             	м         	2003-07-18	+79311001103        
105	Ирина               	Васильевна          	Смирнова            	ж         	2002-11-21	+79311001104        
106	Евгений             	Ильич               	Иванов              	м         	2001-03-08	+79311001105        
107	Надежда             	Андреевна           	Соколова            	ж         	2000-09-05	+79311001106        
108	Игорь               	Николаевич          	Попов               	м         	2002-04-12	+79311001107        
109	Наталья             	Ивановна            	Кузнецова           	ж         	2004-08-30	+79311001108        
110	Максим              	Владимирович        	Петров              	м         	2006-01-17	+79311001109        
111	Мария               	Ивановна            	Васильева           	ж         	2003-05-22	+79311001110        
112	Александр           	Сергеевич           	Семенов             	м         	2001-10-07	+79311001111        
113	Екатерина           	Ивановна            	Королева            	ж         	2005-12-19	+79311001112        
114	Владислав           	Дмитриевич          	Михайлов            	м         	2000-02-25	+79311001113        
115	Анна                	Валентиновна        	Богданова           	ж         	2002-06-09	+79311001114        
116	Павел               	Павлович            	Егоров              	м         	2004-08-03	+79311001115        
117	Светлана            	Викторовна          	Дмитриева           	ж         	2001-11-11	+79311001116        
118	Александр           	Николаевич          	Куликов             	м         	2003-03-27	+79311001117        
119	Евгения             	Андреевна           	Захарова            	ж         	2000-07-01	+79311001118        
120	Алексей             	Алексеевич          	Тарасов             	м         	2005-10-16	+79311001119        
121	Людмила             	Петровна            	Жукова              	ж         	2002-01-08	+79311001120        
122	Сергей              	Васильевич          	Романов             	м         	2004-05-19	+79311001121        
123	Ирина               	Владимировна        	Степанова           	ж         	2006-08-28	+79311001122        
124	Дмитрий             	Дмитриевич          	Соловьев            	м         	2003-11-07	+79311001123        
125	Елена               	Александровна       	Белова              	ж         	2000-02-13	+79311001124        
126	Виктор              	Иванович            	Воробьев            	м         	2005-04-20	+79311001125        
127	Юлия                	Владимировна        	Киселева            	ж         	2001-09-06	+79311001126        
128	Денис               	Александрович       	Новиков             	м         	2004-12-17	+79311001127        
129	Ангелина            	Викторовна          	Макарова            	ж         	2006-03-28	+79311001128        
130	Станислав           	Васильевич          	Кузнецов            	м         	2000-05-05	+79311001129        
131	Екатерина           	Андреевна           	Тимофеева           	ж         	2002-08-14	+79311001130        
132	Артем               	Валерьевич          	Сергеев             	м         	2003-11-23	+79311001131        
133	Надежда             	Ивановна            	Павлова             	ж         	2001-02-02	+79311001132        
134	Михаил              	Васильевич          	Марков              	м         	2004-06-10	+79311001133        
135	Ольга               	Игоревна            	Федорова            	ж         	2006-09-18	+79311001134        
136	Алексей             	Сергеевич           	Алексеев            	м         	2000-12-01	+79311001135        
137	Елена               	Алексеевна          	Горбунова           	ж         	2002-04-09	+79311001136        
138	Сергей              	Васильевич          	Куликов             	м         	2005-07-16	+79311001137        
139	Ольга               	Васильевна          	Новикова            	ж         	2003-10-21	+79311001138        
140	Дмитрий             	Иванович            	Мартынов            	м         	2001-01-28	+79311001139        
141	Ирина               	Александровна       	Морозова            	ж         	2004-05-03	+79311001140        
142	Анатолий            	Александрович       	Федоров             	м         	2006-08-11	+79311001141        
143	Светлана            	Валерьевна          	Полякова            	ж         	2000-11-17	+79311001142        
144	Павел               	Владимирович        	Степанов            	м         	2002-02-25	+79311001143        
145	Лариса              	Игоревна            	Беляева             	ж         	2005-06-03	+79311001144        
146	Николай             	Васильевич          	Воронин             	м         	2003-09-08	+79311001145        
147	Оксана              	Игоревна            	Соколова            	ж         	2001-12-19	+79311001146        
148	Игорь               	Владимирович        	Миронов             	м         	2004-03-28	+79311001147        
149	Анастасия           	Сергеевна           	Козлова             	ж         	2006-07-05	+79311001148        
150	Алексей             	Александрович       	Белов               	м         	2000-10-13	+79311001149        
151	Татьяна             	Ивановна            	Максимова           	ж         	2002-01-21	+79311001150        
152	Максим              	Андреевич           	Медведев            	м         	2005-04-29	+79311001151        
153	Наталья             	Васильевна          	Кузнецова           	ж         	2003-08-06	+79311001152        
154	Артем               	Владимирович        	Матвеев             	м         	2006-11-16	+79311001153        
155	Екатерина           	Сергеевна           	Николаева           	ж         	2001-02-25	+79311001154        
156	Игорь               	Александрович       	Григорьев           	м         	2004-06-04	+79311001155        
157	Елена               	Владимировна        	Комарова            	ж         	2002-09-11	+79311001156        
158	Михаил              	Сергеевич           	Киселев             	м         	2005-12-21	+79311001157        
159	Татьяна             	Владимировна        	Миронова            	ж         	2000-03-28	+79311001158        
160	Сергей              	Васильевич          	Фролов              	м         	2003-07-07	+79311001159        
161	Анастасия           	Владимировна        	Кудрявцева          	ж         	2001-10-13	+79311001160        
162	Артем               	Сергеевич           	Ковалев             	м         	2005-01-19	+79311001161        
163	Елена               	Анатольевна         	Громова             	ж         	2002-04-28	+79311001162        
164	Максим              	Васильевич          	Савельев            	м         	2006-08-06	+79311001163        
165	Мария               	Алексеевна          	Кондратьева         	ж         	2000-11-14	+79311001164        
166	Александр           	Станиславович       	Мельников           	м         	2003-02-21	+79311001165        
167	Наталья             	Сергеевна           	Тихонова            	ж         	2005-05-30	+79311001166        
168	Илья                	Владимирович        	Денисов             	м         	2001-09-06	+79311001167        
169	Надежда             	Александровна       	Ширяева             	ж         	2004-12-15	+79311001168        
170	Геннадий            	Викторович          	Филиппов            	м         	2000-03-23	+79311001169        
171	Екатерина           	Васильевна          	Филиппова           	ж         	2002-06-01	+79311001170        
172	Алексей             	Игоревич            	Богданов            	м         	2003-09-11	+79311001171        
173	Надежда             	Игоревна            	Карпова             	ж         	2005-12-19	+79311001172        
174	Сергей              	Владимирович        	Жуков               	м         	2001-04-27	+79311001173        
175	Ольга               	Викторовна          	Белова              	ж         	2004-08-05	+79311001174        
176	Владимир            	Иванович            	Лазарев             	м         	2006-11-13	+79311001175        
177	Оксана              	Игоревна            	Попова              	ж         	2000-02-21	+79311001176        
178	Игорь               	Владимирович        	Власов              	м         	2002-05-30	+79311001177        
179	Марина              	Викторовна          	Суворова            	ж         	2003-09-08	+79311001178        
180	Дмитрий             	Валерьевич          	Федоров             	м         	2005-12-16	+79311001179        
181	Анастасия           	Александровна       	Петрова             	ж         	2001-04-25	+79311001180        
182	Андрей              	Сергеевич           	Пономарев           	м         	2004-08-03	+79311001181        
183	Наталья             	Владимировна        	Шубина              	ж         	2006-11-12	+79311001182        
184	Михаил              	Владимирович        	Фролов              	м         	2000-02-20	+79311001183        
185	Светлана            	Владимировна        	Сорокина            	ж         	2002-05-29	+79311001184        
186	Александр           	Иванович            	Логинов             	м         	2003-09-06	+79311001185        
187	Екатерина           	Владимировна        	Блинова             	ж         	2005-12-15	+79311001186        
188	Денис               	Александрович       	Чернов              	м         	2001-04-24	+79311001187        
189	Ирина               	Викторовна          	Васильева           	ж         	2004-08-02	+79311001188        
190	Алексей             	Владимирович        	Степанов            	м         	2006-11-10	+79311001189        
191	Надежда             	Сергеевна           	Григорьева          	ж         	2000-02-18	+79311001190        
192	Игорь               	Владимирович        	Кузьмин             	м         	2002-05-28	+79311001191        
193	Ольга               	Александровна       	Маркова             	ж         	2003-09-06	+79311001192        
194	Максим              	Викторович          	Кудрявцев           	м         	2005-12-14	+79311001193        
195	Елена               	Сергеевна           	Симонова            	ж         	2001-04-23	+79311001194        
196	Дмитрий             	Игоревич            	Федотов             	м         	2004-08-01	+79311001195        
197	Александра          	Александровна       	Жукова              	ж         	2006-11-09	+79311001196        
198	Михаил              	Владимирович        	Панов               	м         	2000-02-17	+79311001197        
199	Анна                	Александровна       	Дмитриева           	ж         	2002-05-27	+79311001198        
200	Денис               	Владимирович        	Голубев             	м         	2003-09-06	+79311001199        
201	Наталья             	Владимировна        	Морозова            	ж         	1968-05-03	+79311001200        
202	Алексей             	Васильевич          	Романов             	м         	1979-11-15	+79311001201        
203	Татьяна             	Викторовна          	Орлова              	ж         	1967-07-27	+79311001202        
204	Владимир            	Сергеевич           	Щербаков            	м         	1964-12-08	+79311001203        
205	Ольга               	Владимировна        	Назарова            	ж         	1961-09-21	+79311001204        
206	Андрей              	Владимирович        	Беляев              	м         	1965-03-10	+79311001205        
207	Наталья             	Александровна       	Гришина             	ж         	1963-10-18	+79311001206        
208	Виктор              	Владимирович        	Крылов              	м         	1966-07-02	+79311001207        
209	Мария               	Игоревна            	Давыдова            	ж         	1962-04-09	+79311001208        
210	Игорь               	Валентинович        	Артемьев            	м         	1977-05-20	+79311001209        
211	Марина              	Алексеевна          	Нестерова           	ж         	1976-08-28	+79311001210        
212	Павел               	Сергеевич           	Симонов             	м         	1974-01-05	+79311001211        
213	Светлана            	Сергеевна           	Максимова           	ж         	1973-06-11	+79311001212        
214	Сергей              	Валентинович        	Фомин               	м         	1969-02-14	+79311001213        
215	Наталья             	Игоревна            	Медведева           	ж         	1971-11-22	+79311001214        
216	Анатолий            	Алексеевич          	Власов              	м         	1960-09-01	+79311001215        
217	Елена               	Игоревна            	Матвеева            	ж         	1968-12-17	+79311001216        
218	Иван                	Викторович          	Куликов             	м         	1972-03-29	+79311001217        
219	Оксана              	Владимировна        	Сорокина            	ж         	1978-08-07	+79311001218        
220	Алексей             	Александрович       	Сергеев             	м         	1975-06-25	+79311001219        
221	Татьяна             	Ивановна            	Пономарева          	ж         	1970-10-30	+79311001220        
222	Александр           	Владимирович        	Голубев             	м         	1976-04-12	+79311001221        
223	Вера                	Владимировна        	Федотова            	ж         	1970-01-23	+79311001222        
224	Андрей              	Сергеевич           	Савельев            	м         	1974-11-03	+79311001223        
225	Евгения             	Владимировна        	Чернова             	ж         	1961-07-19	+79311001224        
226	Владимир            	Васильевич          	Ковалев             	м         	1969-05-04	+79311001225        
227	Ольга               	Андреевна           	Щербакова           	ж         	1972-12-15	+79311001226        
228	Николай             	Анатольевич         	Назаров             	м         	1977-03-08	+79311001227        
229	Елена               	Васильевна          	Беляева             	ж         	1979-09-26	+79311001228        
230	Андрей              	Сергеевич           	Крылов              	м         	1971-10-09	+79311001229        
231	Екатерина           	Андреевна           	Давыдова            	ж         	1975-06-18	+79311001230        
232	Алексей             	Игоревич            	Артемьев            	м         	1964-02-21	+79311001231        
233	Татьяна             	Владимировна        	Нестерова           	ж         	1963-11-05	+79311001232        
234	Владимир            	Викторович          	Симонов             	м         	1967-08-14	+79311001233        
235	Ольга               	Алексеевна          	Максимова           	ж         	1962-04-27	+79311001234        
236	Андрей              	Васильевич          	Фомин               	м         	1966-09-10	+79311001235        
237	Наталья             	Владимировна        	Медведева           	ж         	1971-01-22	+79311001236        
238	Виктор              	Иванович            	Власов              	м         	1965-07-01	+79311001237        
239	Светлана            	Александровна       	Матвеева            	ж         	1968-03-13	+79311001238        
240	Геннадий            	Сергеевич           	Куликов             	м         	1961-11-28	+79311001239        
241	Мария               	Валентиновна        	Сорокина            	ж         	1970-05-06	+79311001240        
242	Александр           	Игоревич            	Сергеев             	м         	1964-10-19	+79311001241        
243	Елена               	Александровна       	Пономарева          	ж         	1963-12-07	+79311001242        
244	Дмитрий             	Васильевич          	Голубев             	м         	1967-08-15	+79311001243        
245	Анастасия           	Сергеевна           	Савельева           	ж         	1978-01-30	+79311001244        
246	Иван                	Владимирович        	Чернов              	м         	1974-06-08	+79311001245        
247	Татьяна             	Александровна       	Ковалева            	ж         	1962-03-20	+79311001246        
248	Владимир            	Игоревич            	Щербаков            	м         	1960-09-02	+79311001247        
249	Ольга               	Васильевна          	Назарова            	ж         	1969-04-11	+79311001248        
250	Андрей              	Владимирович        	Беляев              	м         	1976-11-23	+79311001249        
251	Наталья             	Александровна       	Гришина             	ж         	1973-07-05	+79311001250        
252	Алексей             	Валентинович        	Крылов              	м         	1977-02-16	+79311001251        
253	Марина              	Игоревна            	Давыдова            	ж         	1972-10-28	+79311001252        
254	Игорь               	Владимирович        	Артемьев            	м         	1968-04-09	+79311001253        
255	Мария               	Валерьевна          	Нестерова           	ж         	1975-09-22	+79311001254        
256	Павел               	Владимирович        	Симонов             	м         	1972-01-03	+79311001255        
257	Светлана            	Владимировна        	Максимова           	ж         	1966-06-14	+79311001256        
258	Сергей              	Валентинович        	Фомин               	м         	1978-12-26	+79311001257        
259	Наталья             	Игоревна            	Медведева           	ж         	1965-08-07	+79311001258        
260	Анатолий            	Алексеевич          	Власов              	м         	1974-04-18	+79311001259        
261	Елена               	Игоревна            	Матвеева            	ж         	1970-11-30	+79311001260        
262	Иван                	Викторович          	Куликов             	м         	1977-07-10	+79311001261        
263	Оксана              	Владимировна        	Сорокина            	ж         	1963-03-21	+79311001262        
264	Алексей             	Александрович       	Сергеев             	м         	1968-11-02	+79311001263        
265	Татьяна             	Ивановна            	Пономарева          	ж         	1971-05-13	+79311001264        
266	Александр           	Владимирович        	Голубев             	м         	1973-09-24	+79311001265        
267	Вера                	Владимировна        	Федотова            	ж         	1961-02-06	+79311001266        
268	Андрей              	Сергеевич           	Савельев            	м         	1979-08-17	+79311001267        
269	Евгения             	Владимировна        	Чернова             	ж         	1967-04-29	+79311001268        
270	Владимир            	Васильевич          	Ковалев             	м         	1969-12-10	+79311001269        
271	Ольга               	Андреевна           	Щербакова           	ж         	1967-05-12	+79311001270        
272	Николай             	Анатольевич         	Назаров             	м         	1972-11-23	+79311001271        
273	Елена               	Васильевна          	Беляева             	ж         	1975-08-04	+79311001272        
274	Андрей              	Сергеевич           	Крылов              	м         	1968-03-15	+79311001273        
275	Екатерина           	Андреевна           	Давыдова            	ж         	1963-09-26	+79311001274        
276	Алексей             	Игоревич            	Артемьев            	м         	1971-04-08	+79311001275        
277	Татьяна             	Владимировна        	Нестерова           	ж         	1976-10-20	+79311001276        
278	Владимир            	Викторович          	Симонов             	м         	1973-07-01	+79311001277        
279	Ольга               	Алексеевна          	Максимова           	ж         	1969-02-13	+79311001278        
280	Андрей              	Васильевич          	Фомин               	м         	1974-06-25	+79311001279        
281	Наталья             	Владимировна        	Медведева           	ж         	1978-01-06	+79311001280        
282	Виктор              	Иванович            	Власов              	м         	1970-08-17	+79311001281        
283	Светлана            	Александровна       	Матвеева            	ж         	1975-04-29	+79311001282        
284	Геннадий            	Сергеевич           	Куликов             	м         	1961-12-10	+79311001283        
285	Мария               	Валентиновна        	Сорокина            	ж         	1965-07-21	+79311001284        
286	Александр           	Игоревич            	Сергеев             	м         	1979-03-03	+79311001285        
287	Елена               	Александровна       	Пономарева          	ж         	1971-11-14	+79311001286        
288	Дмитрий             	Васильевич          	Голубев             	м         	1960-05-26	+79311001287        
289	Анастасия           	Сергеевна           	Савельева           	ж         	1976-10-07	+79311001288        
290	Иван                	Владимирович        	Чернов              	м         	1973-04-18	+79311001289        
291	Татьяна             	Александровна       	Ковалева            	ж         	1969-11-30	+79311001290        
292	Владимир            	Игоревич            	Щербаков            	м         	1975-07-11	+79311001291        
293	Ольга               	Васильевна          	Назарова            	ж         	1972-02-22	+79311001292        
294	Андрей              	Владимирович        	Беляев              	м         	1970-09-04	+79311001293        
295	Наталья             	Александровна       	Гришина             	ж         	1977-03-15	+79311001294        
296	Алексей             	Валентинович        	Крылов              	м         	1964-08-27	+79311001295        
297	Марина              	Игоревна            	Давыдова            	ж         	1968-05-09	+79311001296        
298	Игорь               	Владимирович        	Артемьев            	м         	1973-11-20	+79311001297        
299	Мария               	Валерьевна          	Нестерова           	ж         	1979-07-02	+79311001298        
300	Павел               	Владимирович        	Симонов             	м         	1971-12-13	+79311001299        
301	Светлана            	Владимировна        	Максимова           	ж         	1978-06-25	+79311001300        
302	Сергей              	Валентинович        	Фомин               	м         	1962-02-07	+79311001301        
303	Наталья             	Игоревна            	Медведева           	ж         	1974-10-18	+79311001302        
304	Анатолий            	Алексеевич          	Власов              	м         	1966-04-30	+79311001303        
305	Елена               	Игоревна            	Матвеева            	ж         	1970-11-11	+79311001304        
306	Иван                	Викторович          	Куликов             	м         	1976-08-23	+79311001305        
307	Оксана              	Владимировна        	Сорокина            	ж         	1969-04-04	+79311001306        
308	Алексей             	Александрович       	Сергеев             	м         	1972-12-16	+79311001307        
309	Татьяна             	Ивановна            	Пономарева          	ж         	1978-07-27	+79311001308        
310	Александр           	Владимирович        	Голубев             	м         	1965-03-08	+79311001309        
311	Вера                	Владимировна        	Федотова            	ж         	1977-09-19	+79311001310        
312	Андрей              	Сергеевич           	Савельев            	м         	1974-05-01	+79311001311        
313	Евгения             	Владимировна        	Чернова             	ж         	1961-01-12	+79311001312        
314	Владимир            	Васильевич          	Ковалев             	м         	1975-07-23	+79311001313        
315	Ольга               	Андреевна           	Щербакова           	ж         	1979-02-05	+79311001314        
316	Николай             	Анатольевич         	Назаров             	м         	1971-10-16	+79311001315        
317	Елена               	Васильевна          	Беляева             	ж         	1976-04-28	+79311001316        
318	Андрей              	Сергеевич           	Крылов              	м         	1964-12-10	+79311001317        
319	Екатерина           	Андреевна           	Давыдова            	ж         	1970-08-21	+79311001318        
320	Алексей             	Игоревич            	Артемьев            	м         	1973-04-02	+79311001319        
321	Татьяна             	Владимировна        	Нестерова           	ж         	1969-11-14	+79311001320        
322	Владимир            	Викторович          	Симонов             	м         	1978-05-26	+79311001321        
323	Ольга               	Алексеевна          	Максимова           	ж         	1972-01-07	+79311001322        
324	Андрей              	Васильевич          	Фомин               	м         	1975-09-18	+79311001323        
325	Наталья             	Владимировна        	Медведева           	ж         	1962-03-30	+79311001324        
326	Виктор              	Иванович            	Власов              	м         	1967-10-11	+79311001325        
327	Светлана            	Александровна       	Матвеева            	ж         	1974-06-23	+79311001326        
328	Геннадий            	Сергеевич           	Куликов             	м         	1979-12-05	+79311001327        
329	Мария               	Валентиновна        	Сорокина            	ж         	1971-07-17	+79311001328        
330	Александр           	Игоревич            	Сергеев             	м         	1965-02-28	+79311001329        
331	Елена               	Александровна       	Пономарева          	ж         	1978-08-10	+79311001330        
332	Дмитрий             	Васильевич          	Голубев             	м         	1973-04-22	+79311001331        
333	Анастасия           	Сергеевна           	Савельева           	ж         	1960-11-04	+79311001332        
334	Иван                	Владимирович        	Чернов              	м         	1976-09-15	+79311001333        
335	Татьяна             	Александровна       	Ковалева            	ж         	1971-03-27	+79311001334        
336	Владимир            	Игоревич            	Щербаков            	м         	1964-12-08	+79311001335        
337	Ольга               	Васильевна          	Назарова            	ж         	1979-06-20	+79311001336        
338	Андрей              	Владимирович        	Беляев              	м         	1972-02-01	+79311001337        
339	Наталья             	Александровна       	Гришина             	ж         	1974-10-13	+79311001338        
340	Алексей             	Валентинович        	Крылов              	м         	1963-04-25	+79311001339        
341	Марина              	Игоревна            	Давыдова            	ж         	1978-11-07	+79311001340        
342	Игорь               	Владимирович        	Артемьев            	м         	1970-07-18	+79311001341        
343	Мария               	Валерьевна          	Нестерова           	ж         	1977-03-09	+79311001342        
344	Павел               	Владимирович        	Симонов             	м         	1963-11-20	+79311001343        
345	Светлана            	Владимировна        	Максимова           	ж         	1972-07-01	+79311001344        
346	Сергей              	Валентинович        	Фомин               	м         	1968-02-12	+79311001345        
347	Наталья             	Игоревна            	Медведева           	ж         	1973-09-23	+79311001346        
348	Анатолий            	Алексеевич          	Власов              	м         	1978-05-05	+79311001347        
349	Елена               	Игоревна            	Матвеева            	ж         	1970-01-16	+79311001348        
350	Иван                	Викторович          	Куликов             	м         	1975-07-27	+79311001349        
351	Оксана              	Владимировна        	Сорокина            	ж         	1971-04-08	+79311001350        
352	Алексей             	Александрович       	Сергеев             	м         	1960-12-19	+79311001351        
353	Татьяна             	Ивановна            	Пономарева          	ж         	1976-08-31	+79311001352        
354	Александр           	Владимирович        	Голубев             	м         	1972-03-12	+79311001353        
355	Вера                	Владимировна        	Федотова            	ж         	1968-10-24	+79311001354        
356	Андрей              	Сергеевич           	Савельев            	м         	1974-06-06	+79311001355        
357	Евгения             	Владимировна        	Чернова             	ж         	1966-01-17	+79311001356        
358	Владимир            	Васильевич          	Ковалев             	м         	1971-07-28	+79311001357        
359	Ольга               	Андреевна           	Щербакова           	ж         	1968-02-09	+79311001358        
360	Николай             	Анатольевич         	Назаров             	м         	1975-09-20	+79311001359        
361	Елена               	Васильевна          	Беляева             	ж         	1979-05-02	+79311001360        
362	Андрей              	Сергеевич           	Крылов              	м         	1971-12-13	+79311001361        
363	Екатерина           	Андреевна           	Давыдова            	ж         	1978-06-25	+79311001362        
364	Алексей             	Игоревич            	Артемьев            	м         	1972-02-06	+79311001363        
365	Татьяна             	Владимировна        	Нестерова           	ж         	1975-08-17	+79311001364        
366	Владимир            	Викторович          	Симонов             	м         	1971-04-29	+79311001365        
367	Ольга               	Алексеевна          	Максимова           	ж         	1978-11-10	+79311001366        
368	Андрей              	Васильевич          	Фомин               	м         	1964-07-22	+79311001367        
369	Наталья             	Владимировна        	Медведева           	ж         	1970-03-03	+79311001368        
370	Виктор              	Иванович            	Власов              	м         	1975-11-14	+79311001369        
371	Светлана            	Александровна       	Матвеева            	ж         	1972-05-26	+79311001370        
372	Геннадий            	Сергеевич           	Куликов             	м         	1968-01-07	+79311001371        
373	Мария               	Валентиновна        	Сорокина            	ж         	1973-09-18	+79311001372        
374	Александр           	Игоревич            	Сергеев             	м         	1979-04-30	+79311001373        
375	Елена               	Александровна       	Пономарева          	ж         	1971-12-11	+79311001374        
376	Дмитрий             	Васильевич          	Голубев             	м         	1978-06-22	+79311001375        
377	Анастасия           	Сергеевна           	Савельева           	ж         	1972-02-04	+79311001376        
378	Иван                	Владимирович        	Чернов              	м         	1974-10-15	+79311001377        
379	Татьяна             	Александровна       	Ковалева            	ж         	1971-04-27	+79311001378        
380	Владимир            	Игоревич            	Щербаков            	м         	1976-11-08	+79311001379        
381	Ольга               	Васильевна          	Назарова            	ж         	1964-07-20	+79311001380        
382	Андрей              	Владимирович        	Беляев              	м         	1960-04-01	+79311001381        
383	Наталья             	Александровна       	Гришина             	ж         	1973-12-12	+79311001382        
384	Алексей             	Валентинович        	Крылов              	м         	1966-08-24	+79311001383        
385	Марина              	Игоревна            	Давыдова            	ж         	1972-05-05	+79311001384        
386	Игорь               	Владимирович        	Артемьев            	м         	1968-01-16	+79311001385        
387	Мария               	Валерьевна          	Нестерова           	ж         	1975-09-27	+79311001386        
388	Павел               	Владимирович        	Симонов             	м         	1971-04-09	+79311001387        
389	Светлана            	Владимировна        	Максимова           	ж         	1976-12-20	+79311001388        
390	Сергей              	Валентинович        	Фомин               	м         	1970-08-01	+79311001389        
391	Наталья             	Игоревна            	Медведева           	ж         	1964-03-12	+79311001390        
392	Анатолий            	Алексеевич          	Власов              	м         	1969-10-23	+79311001391        
393	Елена               	Игоревна            	Матвеева            	ж         	1975-06-04	+79311001392        
394	Иван                	Викторович          	Куликов             	м         	1968-01-15	+79311001393        
395	Оксана              	Владимировна        	Сорокина            	ж         	1973-07-26	+79311001394        
396	Алексей             	Александрович       	Сергеев             	м         	1979-02-07	+79311001395        
397	Татьяна             	Ивановна            	Пономарева          	ж         	1971-10-18	+79311001396        
398	Александр           	Владимирович        	Голубев             	м         	1966-04-29	+79311001397        
399	Вера                	Владимировна        	Федотова            	ж         	1970-11-10	+79311001398        
400	Андрей              	Сергеевич           	Савельев            	м         	1975-07-22	+79311001399        
\.


                                                                                                                                                                                                                                                      4913.dat                                                                                            0000600 0004000 0002000 00000022251 14630037536 0014263 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	1	Иванов              	Петр                	Алексеевич          	1987-05-12	40000	Продавец            
2	1	Петров              	Иван                	Сергеевич           	1992-09-03	45000	Тренер              
3	2	Сидоров             	Алексей             	Владимирович        	1985-11-28	42000	Тренер              
4	3	Кузнецов            	Дмитрий             	Николаевич          	1979-06-17	43000	Тренер              
5	2	Васильев            	Сергей              	Иванович            	1990-08-05	41000	Тренер              
6	2	Смирнов             	Андрей              	Петрович            	1983-03-20	42000	Продавец            
7	3	Попова              	Ольга               	Александровна       	1988-09-14	40000	Тренер              
8	1	Козлов              	Никита              	Дмитриевич          	1977-07-02	45000	Тренер              
9	3	Лебедева            	Мария               	Владимировна        	1984-04-23	41000	Тренер              
10	2	Новиков             	Егор                	Александрович       	1981-12-09	43000	Тренер              
11	3	Иванова             	Елена               	Петровна            	1975-10-15	42000	Продавец            
12	3	Петрова             	Анна                	Ивановна            	1989-07-08	43000	Тренер              
13	4	Сидорова            	Наталья             	Александровна       	1982-03-25	41000	Тренер              
14	5	Кузнецова           	Ольга               	Сергеевна           	1978-09-19	40000	Тренер              
15	5	Васильева           	Марина              	Викторовна          	1986-12-07	45000	Тренер              
16	4	Смирнова            	Ирина               	Дмитриевна          	1973-05-30	42000	Продавец            
17	5	Попов               	Станислав           	Васильевич          	1970-08-28	43000	Тренер              
18	1	Козлова             	Оксана              	Алексеевна          	1976-04-11	41000	Тренер              
19	5	Лебедев             	Алексей             	Павлович            	1985-01-02	40000	Тренер              
20	6	Новиков             	Павел               	Владимирович        	1988-06-24	45000	Тренер              
21	5	Иванова             	Татьяна             	Алексеевна          	1979-09-13	42000	Продавец            
22	10	Петрова             	Екатерина           	Игоревна            	1983-05-26	43000	Тренер              
23	2	Сидоров             	Артем               	Васильевич          	1987-12-08	41000	Тренер              
24	10	Кузнецова           	Любовь              	Николаевна          	1974-07-17	40000	Тренер              
25	4	Васильева           	Нина                	Петровна            	1980-04-04	45000	Тренер              
26	6	Смирнов             	Владимир            	Сергеевич           	1971-10-29	42000	Продавец            
27	10	Попова              	Галина              	Дмитриевна          	1986-02-12	43000	Тренер              
28	6	Козлов              	Валентин            	Анатольевич         	1982-11-23	41000	Тренер              
29	1	Лебедева            	Светлана            	Васильевна          	1977-08-05	40000	Тренер              
30	9	Новикова            	Вера                	Геннадьевна         	1984-03-16	45000	Тренер              
31	7	Иванов              	Максим              	Владимирович        	1972-06-27	42000	Продавец            
32	9	Петров              	Игорь               	Аркадьевич          	1981-01-09	43000	Тренер              
33	4	Сидоров             	Степан              	Павлович            	1978-04-20	41000	Тренер              
34	8	Кузнецов            	Денис               	Алексеевич          	1985-11-01	40000	Продавец            
35	8	Васильев            	Александр           	Владимирович        	1973-07-14	55000	Тренер              
36	4	Смирнов             	Даниил              	Иванович            	1980-02-25	42000	Тренер              
37	8	Попов               	Павел               	Станиславович       	1976-09-06	43000	Тренер              
38	9	Козлов              	Михаил              	Алексеевич          	1983-12-17	41000	Тренер              
39	9	Лебедев             	Иван                	Александрович       	1975-05-28	40000	Тренер              
40	8	Новиков             	Артем               	Сергеевич           	1980-10-09	45000	Тренер              
41	9	Иванова             	София               	Аркадьевна          	1977-03-20	42000	Продавец            
42	8	Петрова             	Алина               	Васильевна          	1984-08-01	43000	Тренер              
43	7	Сидоров             	Антон               	Дмитриевич          	1979-01-12	41000	Тренер              
44	10	Кузнецова           	Маргарита           	Петровна            	1986-06-23	40000	Продавец            
45	7	Васильева           	Елена               	Игоревна            	1974-09-04	55000	Тренер              
46	7	Смирнов             	Сергей              	Павлович            	1981-02-15	42000	Тренер              
47	6	Попов               	Андрей              	Александрович       	1970-07-26	43000	Тренер              
48	7	Козлов              	Илья                	Даниилович          	1977-12-07	41000	Тренер              
49	6	Лебедева            	Тамара              	Владимировна        	1982-05-18	40000	Тренер              
50	1	Кустарев            	Александр           	Павлович            	2004-09-12	100000	Директор            
51	2	Иванов              	Иван                	Иванович,           	1985-01-10	100000	Директор            
52	3	Петров              	Петр                	Петрович,           	1990-02-23	110000	Директор            
53	4	Сидорова            	Мария               	Ивановна,           	1995-03-15	100000	Директор            
54	5	Васильев            	Алексей             	Николаевич,         	1982-04-29	100000	Директор            
55	6	Романова            	Елена               	Васильевна,         	1978-05-06	100000	Директор            
56	7	Кузнецов            	Сергей              	Александрович,      	1987-06-11	120000	Директор            
57	8	Смирнова            	Дарья               	Михайловна,         	1992-07-24	100000	Директор            
58	9	Николаев            	Игорь               	Олегович,           	1981-08-09	100000	Директор            
59	10	Федорова            	Анна                	Петровна,           	1985-09-30	100000	Директор            
60	1	Лебедева            	Светлана            	Олеговна,           	1979-10-12	60000	Менеджер            
61	2	Морозова            	Юлия                	Сергеевна,          	1988-11-28	50000	Менеджер            
62	3	Егоров              	Владимир            	Петрович,           	1993-12-19	60000	Менеджер            
63	4	Козлова             	Ирина               	Алексеевна,         	1984-01-04	55000	Менеджер            
64	5	Соловьева           	Татьяна             	Владимировна,       	1991-02-22	45000	Менеджер            
65	6	Макаров             	Дмитрий             	Игоревич,           	1986-03-15	55000	Менеджер            
66	7	Захарова            	Вера                	Борисовна,          	1982-04-30	43000	Менеджер            
67	8	Новикова            	Екатерина           	Андреевна,          	1975-05-09	55000	Менеджер            
68	9	Попова              	Надежда             	Викторовна,         	1989-06-23	43000	Менеджер            
69	10	Горбунова           	Людмила             	Михайловна,         	1996-07-11	55000	Менеджер            
\.


                                                                                                                                                                                                                                                                                                                                                       4920.dat                                                                                            0000600 0004000 0002000 00000003161 14630037536 0014260 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        22	1
29	1
32	1
17	3
20	3
23	3
7	4
15	6
43	6
19	8
28	8
15	9
37	9
38	10
41	11
19	12
32	12
37	13
43	13
22	14
29	14
33	15
10	17
47	18
17	20
27	20
49	21
7	22
39	23
13	24
31	25
16	26
40	30
41	30
7	32
37	33
35	2
15	35
24	35
38	35
35	37
2	41
18	41
40	2
41	42
7	43
35	44
40	44
41	44
42	44
41	2
1	46
8	46
18	46
36	47
33	47
39	47
42	2
40	48
41	48
17	49
26	50
3	5
5	50
14	5
30	5
6	50
31	5
9	50
13	50
25	50
26	51
3	58
40	60
42	60
42	61
26	57
20	63
5	66
26	66
1	71
12	71
3	69
14	69
30	69
31	69
31	70
19	73
28	73
32	73
17	74
23	74
19	83
28	83
32	83
15	92
16	92
37	92
43	92
33	100
39	100
15	103
37	103
43	103
46	114
47	114
50	114
34	119
39	119
44	160
50	160
9	175
13	175
8	180
7	181
11	181
25	194
5	57
6	57
9	57
13	57
25	57
26	194
3	195
21	200
30	274
15	62
16	62
24	62
37	62
38	62
44	276
16	279
18	281
15	282
16	282
31	285
44	68
45	68
46	68
47	68
49	68
50	68
15	286
19	326
23	333
46	334
15	381
12	383
25	392
45	394
47	394
49	399
19	120
22	120
28	120
29	120
32	120
5	121
6	121
9	121
13	121
25	121
26	121
1	157
2	157
4	157
8	157
12	157
18	157
7	158
10	158
11	158
48	158
33	167
34	167
36	167
39	167
3	169
14	169
30	169
31	169
44	172
45	172
46	172
47	172
49	172
50	172
17	185
20	185
21	185
23	185
27	185
35	217
40	217
41	217
42	217
5	225
6	225
9	225
13	225
25	225
26	225
5	236
6	236
9	236
13	236
25	236
26	236
7	314
10	314
11	314
48	314
5	325
6	325
9	325
13	325
25	325
26	325
44	328
45	328
46	328
47	328
49	328
50	328
3	337
14	337
30	337
31	337
1	339
2	339
4	339
8	339
12	339
18	339
3	348
14	348
30	348
31	348
19	353
22	353
28	353
29	353
32	353
17	357
20	357
21	357
23	357
27	357
15	361
16	361
24	361
37	361
38	361
43	361
44	395
45	395
46	395
47	395
49	395
50	395
\.


                                                                                                                                                                                                                                                                                                                                                                                                               4919.dat                                                                                            0000600 0004000 0002000 00000003312 14630037536 0014266 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	1	2	Аэробика            
2	1	2	Бокс                
3	3	4	Бокс                
4	1	8	Фитнес              
5	2	23	Аэробика            
6	2	10	Бокс                
7	4	13	Фитнес              
8	1	29	Фитнес              
9	2	10	Кроссфит            
10	4	33	Аэробика            
11	4	25	Бокс                
12	1	29	Кроссфит            
13	2	5	Кроссфит            
14	3	7	Бокс                
15	6	20	Кроссфит            
16	6	20	Кроссфит            
17	7	43	Аэробика            
18	1	29	Бокс                
19	8	40	Танцы               
20	7	46	Танцы               
21	7	46	Борьба              
22	8	40	Борьба              
23	7	48	Борьба              
24	6	49	Йога                
25	2	3	Танцы               
26	2	3	Батуты              
27	7	48	Растяжка            
28	8	37	Аэробика            
29	8	37	Бокс                
30	3	12	Батуты              
31	3	12	Танцы               
32	8	40	Танцы               
33	10	24	Батуты              
34	10	27	Растяжка            
35	9	30	Бокс                
36	10	27	Аэробика            
37	6	49	Батуты              
38	6	49	Танцы               
39	10	24	Батуты              
40	9	38	Бокс                
41	9	39	Йога                
42	9	39	Батуты              
43	6	20	Аэробика            
44	5	14	Борьба              
45	5	15	Йога                
46	5	14	Растяжка            
47	5	14	Йога                
48	4	33	Аэробика            
49	5	14	Бокс                
50	5	14	Бокс                
\.


                                                                                                                                                                                                                                                                                                                      4908.dat                                                                                            0000600 0004000 0002000 00000004163 14630037536 0014271 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	09:00:00	23:00:00	Старая площадь, 8/5с2, Москва                                                                                                                         	+79311001409        
2	09:00:00	23:00:00	Литейный проспект, 30, Санкт-Петербург                                                                                                                	+79311001410        
3	09:00:00	23:00:00	улица Петровка, 5, Москва                                                                                                                             	+79311001411        
4	09:00:00	23:00:00	улица Малышева, 46, Екатеринбург                                                                                                                      	+79311001412        
5	09:00:00	23:00:00	Садовая улица, 18, Санкт-Петербург                                                                                                                    	+79311001413        
6	09:00:00	23:00:00	улица Воздвиженка, 10, Москва                                                                                                                         	+79311001414        
7	09:00:00	23:00:00	Пермская улица, 66, Пермь                                                                                                                             	+79311001415        
8	09:00:00	23:00:00	Малая Бронная улица, 2с1, Москва                                                                                                                      	+79311001416        
9	09:00:00	23:00:00	Владимирский проспект, 3, Санкт-Петербург                                                                                                             	+79311001417        
10	09:00:00	23:00:00	улица Плеханова, 34, Пермь                                                                                                                            	+79311001418        
\.


                                                                                                                                                                                                                                                                                                                                                                                                             4912.dat                                                                                            0000600 0004000 0002000 00000047510 14630037536 0014267 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	4	1	6	9	60	10200	2023-04-23	2023-04-24	нет
2	1	2	6	3	30	3450	2023-04-24	2023-04-25	нет
3	5	3	6	6	30	6750	2023-04-25	2023-04-26	нет
4	5	4	6	10	60	11300	2023-04-26	2023-04-27	нет
5	1	5	6	5	30	5650	2023-04-27	2023-04-28	нет
6	2	6	6	11	60	12400	2023-04-28	2023-04-29	нет
7	7	7	6	4	30	4550	2023-04-29	2023-04-30	нет
8	6	8	6	6	30	6750	2023-04-30	2023-05-01	нет
9	3	9	6	2	30	2350	2023-05-01	2023-05-02	нет
10	2	10	6	9	60	10200	2023-05-02	2023-05-03	нет
11	1	11	6	11	60	12400	2023-05-03	2023-05-04	нет
12	10	12	6	1	0	1100	2023-05-04	2023-05-05	нет
13	10	13	6	7	30	7850	2023-05-05	2023-05-06	нет
14	8	14	6	2	30	2350	2023-05-06	2023-05-07	нет
15	1	15	6	5	30	5650	2023-05-07	2023-05-08	нет
16	2	16	6	4	30	4550	2023-05-08	2023-05-09	нет
17	7	17	6	3	30	3450	2023-05-09	2023-05-10	нет
18	1	18	6	9	60	10200	2023-05-10	2023-05-11	нет
19	4	19	6	6	30	6750	2023-05-11	2023-05-12	нет
20	3	20	6	12	60	13500	2023-05-12	2023-05-13	нет
21	1	21	6	3	30	3450	2023-05-13	2023-05-14	нет
22	7	22	6	8	30	8950	2023-05-14	2023-05-15	нет
23	2	23	6	2	30	2350	2023-05-15	2023-05-16	нет
24	10	24	6	1	0	1100	2023-05-16	2023-05-17	нет
25	3	25	6	5	30	5650	2023-05-17	2023-05-18	нет
26	2	26	6	11	60	12400	2023-05-18	2023-05-19	нет
27	2	27	6	7	30	7850	2023-05-19	2023-05-20	нет
28	7	28	6	9	60	10200	2023-05-20	2023-05-21	нет
29	2	29	6	6	30	6750	2023-05-21	2023-05-22	нет
30	7	30	6	7	30	7850	2023-05-22	2023-05-23	нет
31	4	31	6	11	60	12400	2023-05-23	2023-05-24	нет
32	2	32	6	4	30	4550	2023-05-24	2023-05-25	нет
33	1	33	6	12	60	13500	2023-05-25	2023-05-26	нет
34	8	34	6	10	60	11300	2023-05-26	2023-05-27	нет
35	4	35	6	3	30	3450	2023-05-27	2023-05-28	нет
36	7	36	6	9	60	10200	2023-05-28	2023-05-29	нет
37	8	37	6	8	30	8950	2023-05-29	2023-05-30	нет
38	4	38	6	5	30	5650	2023-05-30	2023-05-31	нет
39	6	39	6	8	30	8950	2023-05-31	2023-06-01	нет
40	1	40	6	7	30	7850	2023-06-01	2023-06-02	нет
41	9	41	6	1	0	1100	2023-06-02	2023-06-03	нет
42	8	42	6	6	30	6750	2023-06-03	2023-06-04	нет
43	6	43	6	4	30	4550	2023-06-04	2023-06-05	нет
44	6	44	6	10	60	11300	2023-06-05	2023-06-06	нет
45	6	45	6	12	60	13500	2023-06-06	2023-06-07	да 
46	3	46	6	1	0	1100	2023-06-07	2023-06-08	нет
47	5	47	6	2	30	2350	2023-06-08	2023-06-09	нет
48	1	48	6	8	30	8950	2023-06-09	2023-06-10	нет
49	1	49	6	4	30	4550	2023-06-10	2023-06-11	нет
50	9	50	6	5	30	5650	2023-06-11	2023-06-12	нет
51	1	51	6	9	60	10200	2023-06-12	2023-06-13	нет
52	2	52	6	7	30	7850	2023-06-13	2023-06-14	нет
53	3	53	6	11	60	12400	2023-06-14	2023-06-15	нет
54	6	54	6	3	30	3450	2023-06-15	2023-06-16	нет
55	4	55	6	11	60	12400	2023-06-16	2023-06-17	нет
56	6	56	6	6	30	6750	2023-06-17	2023-06-18	нет
57	6	57	6	1	0	1100	2023-06-18	2023-06-19	нет
58	4	58	6	12	60	13500	2023-06-19	2023-06-20	да 
59	9	59	6	4	30	4550	2023-06-20	2023-06-21	нет
60	3	60	6	9	60	10200	2023-06-21	2023-06-22	нет
61	1	61	6	8	30	8950	2023-06-22	2023-06-23	нет
62	3	62	6	5	30	5650	2023-06-23	2023-06-24	нет
63	4	63	6	2	30	2350	2023-06-24	2023-06-25	нет
64	6	64	6	7	30	7850	2023-06-25	2023-06-26	нет
65	3	65	6	11	60	12400	2023-06-26	2023-06-27	нет
66	6	66	6	3	30	3450	2023-06-27	2023-06-28	нет
67	7	67	6	10	60	11300	2023-06-28	2023-06-29	нет
68	10	68	6	6	30	6750	2023-06-29	2023-06-30	нет
69	4	69	6	9	60	10200	2023-06-30	2023-07-01	нет
70	8	70	6	4	30	4550	2023-07-01	2023-07-02	нет
71	10	71	6	1	0	1100	2023-07-02	2023-07-03	нет
72	10	72	6	8	30	8950	2023-07-03	2023-07-04	нет
73	5	73	6	5	30	5650	2023-07-04	2023-07-05	нет
74	6	74	6	7	30	7850	2023-07-05	2023-07-06	нет
75	10	75	6	2	30	2350	2023-07-06	2023-07-07	нет
76	2	76	7	3	30	3130	2023-07-07	2023-07-08	нет
77	7	77	7	12	60	12260	2023-07-08	2023-07-09	да 
78	7	78	7	10	60	10260	2023-07-09	2023-07-10	нет
79	10	79	7	11	60	11260	2023-07-10	2023-07-11	да 
80	2	80	7	6	30	6130	2023-07-11	2023-07-12	нет
81	5	81	7	12	60	12260	2023-07-12	2023-07-13	да 
82	5	82	7	3	30	3130	2023-07-13	2023-07-14	нет
83	2	83	7	2	30	2130	2023-07-14	2023-07-15	нет
84	2	84	7	10	60	10260	2023-07-15	2023-07-16	нет
85	4	85	7	9	60	9260	2023-07-16	2023-07-17	нет
86	6	86	7	8	30	8130	2023-07-17	2023-07-18	нет
87	3	87	7	4	30	4130	2023-07-18	2023-07-19	нет
88	5	88	7	1	0	1000	2023-07-19	2023-07-20	нет
89	8	89	7	5	30	5130	2023-07-20	2023-07-21	нет
90	8	90	7	7	30	7130	2023-07-21	2023-07-22	нет
91	5	91	7	6	30	6130	2023-07-22	2023-07-23	нет
92	6	92	7	11	60	11260	2023-07-23	2023-07-24	да 
93	1	93	7	9	60	9260	2023-07-24	2023-07-25	нет
94	10	94	7	4	30	4130	2023-07-25	2023-07-26	нет
95	2	95	7	5	30	5130	2023-07-26	2023-07-27	нет
96	3	96	7	3	30	3130	2023-07-27	2023-07-28	нет
97	5	97	7	8	30	8130	2023-07-28	2023-07-29	нет
98	2	98	7	2	30	2130	2023-07-29	2023-07-30	нет
99	2	99	7	7	30	7130	2023-07-30	2023-07-31	нет
100	4	100	7	1	0	1000	2023-07-31	2023-08-01	нет
101	5	101	7	6	60	6260	2023-08-01	2023-08-02	нет
102	10	102	7	6	30	6130	2023-08-02	2023-08-03	нет
103	6	103	7	8	30	8130	2023-08-03	2023-08-04	нет
104	4	104	7	3	60	3260	2023-08-04	2023-08-05	нет
105	5	105	7	11	30	11130	2023-08-05	2023-08-06	да 
106	4	106	7	8	60	8260	2023-08-06	2023-08-07	нет
107	2	107	7	12	30	12130	2023-08-07	2023-08-08	да 
108	5	108	7	10	30	10130	2023-08-08	2023-08-09	да 
109	1	109	7	12	30	12130	2023-08-09	2023-08-10	да 
110	1	110	7	5	60	5260	2023-08-10	2023-08-11	нет
111	5	111	7	12	60	12260	2023-08-11	2023-08-12	да 
112	7	112	7	5	0	5000	2023-08-12	2023-08-13	нет
113	4	113	7	3	30	3130	2023-08-13	2023-08-14	нет
114	6	114	7	6	30	6130	2023-08-14	2023-08-15	нет
115	4	115	7	3	30	3130	2023-08-15	2023-08-16	нет
116	8	116	7	12	30	12130	2023-08-16	2023-08-17	да 
117	3	117	7	12	30	12130	2023-08-17	2023-08-18	да 
118	6	118	7	7	60	7260	2023-08-18	2023-08-19	нет
119	4	119	7	8	30	8130	2023-08-19	2023-08-20	нет
120	9	120	7	9	60	9260	2023-08-20	2023-08-21	нет
121	5	121	7	5	30	5130	2023-08-21	2023-08-22	нет
122	5	122	7	6	30	6130	2023-08-22	2023-08-23	нет
123	8	123	7	11	30	11130	2023-08-23	2023-08-24	да 
124	5	124	7	11	0	11000	2023-08-24	2023-08-25	да 
125	1	125	7	3	30	3130	2023-08-25	2023-08-26	нет
126	2	126	7	2	60	2260	2023-08-26	2023-08-27	нет
127	9	127	7	1	30	1130	2023-08-27	2023-08-28	нет
128	10	128	7	8	60	8260	2023-08-28	2023-08-29	нет
129	3	129	7	11	30	11130	2023-08-29	2023-08-30	да 
130	6	130	7	10	30	10130	2023-08-30	2023-08-31	да 
131	3	131	7	3	60	3260	2023-08-31	2023-09-01	нет
132	10	132	7	2	30	2130	2023-09-01	2023-09-02	нет
133	5	133	7	6	60	6260	2023-09-02	2023-09-03	нет
134	10	134	7	3	60	3260	2023-09-03	2023-09-04	нет
135	6	135	7	3	30	3130	2023-09-04	2023-09-05	нет
136	5	136	7	10	60	10260	2023-09-05	2023-09-06	да 
137	2	137	7	12	30	12130	2023-09-06	2023-09-07	да 
138	10	138	7	1	30	1130	2023-09-07	2023-09-08	нет
139	8	139	7	11	30	11130	2023-09-08	2023-09-09	да 
140	6	140	7	10	30	10130	2023-09-09	2023-09-10	да 
141	9	141	7	12	0	12000	2023-09-10	2023-09-11	да 
142	8	142	7	12	30	12130	2023-09-11	2023-09-12	да 
143	9	143	7	5	30	5130	2023-09-12	2023-09-13	нет
144	2	144	7	5	60	5260	2023-09-13	2023-09-14	нет
145	2	145	7	1	60	1260	2023-09-14	2023-09-15	нет
146	10	146	7	11	0	11000	2023-09-15	2023-09-16	да 
147	5	147	7	6	30	6130	2023-09-16	2023-09-17	нет
148	4	148	7	8	30	8130	2023-09-17	2023-09-18	нет
149	2	149	7	4	30	4130	2023-09-18	2023-09-19	нет
150	9	150	7	4	30	4130	2023-09-19	2023-09-20	нет
151	9	151	7	10	60	10260	2023-09-20	2023-09-21	да 
152	10	152	7	7	30	7130	2023-09-21	2023-09-22	нет
153	4	153	7	2	60	2260	2023-09-22	2023-09-23	нет
154	2	154	7	10	30	10130	2023-09-23	2023-09-24	да 
155	6	155	7	10	60	10260	2023-09-24	2023-09-25	да 
156	5	156	7	12	30	12130	2023-09-25	2023-09-26	да 
157	10	157	7	10	0	10000	2023-09-26	2023-09-27	да 
158	9	158	7	1	60	1260	2023-09-27	2023-09-28	нет
159	4	159	7	10	30	10130	2023-09-28	2023-09-29	да 
160	8	160	7	10	60	10260	2023-09-29	2023-09-30	да 
161	5	161	7	4	30	4130	2023-09-30	2023-10-01	нет
162	7	162	7	8	30	8130	2023-10-01	2023-10-02	да 
163	3	163	7	10	30	10130	2023-10-02	2023-10-03	да 
164	3	164	7	11	30	11130	2023-10-03	2023-10-04	да 
165	3	165	7	8	60	8260	2023-10-04	2023-10-05	да 
166	5	166	7	4	30	4130	2023-10-05	2023-10-06	нет
167	8	167	7	3	60	3260	2023-10-06	2023-10-07	нет
168	2	168	7	6	30	6130	2023-10-07	2023-10-08	нет
169	2	169	8	6	60	6860	2023-10-08	2023-10-09	нет
170	1	170	8	8	30	8930	2023-10-09	2023-10-10	да 
171	3	171	8	9	0	9900	2023-10-10	2023-10-11	да 
172	7	172	8	2	30	2330	2023-10-11	2023-10-12	нет
173	10	173	8	7	30	7830	2023-10-12	2023-10-13	нет
174	5	174	8	7	30	7830	2023-10-13	2023-10-14	нет
175	6	175	8	8	30	8930	2023-10-14	2023-10-15	да 
176	3	176	8	10	30	11130	2023-10-15	2023-10-16	да 
177	8	177	8	11	60	12360	2023-10-16	2023-10-17	да 
178	3	178	8	9	60	10160	2023-10-17	2023-10-18	да 
179	10	179	8	2	60	2460	2023-10-18	2023-10-19	нет
180	8	180	8	8	30	8930	2023-10-19	2023-10-20	да 
181	6	181	8	7	60	7960	2023-10-20	2023-10-21	нет
182	9	182	8	3	30	3430	2023-10-21	2023-10-22	нет
183	10	183	8	2	30	2330	2023-10-22	2023-10-23	нет
184	2	184	8	1	60	1360	2023-10-23	2023-10-24	нет
185	6	185	8	11	60	12360	2023-10-24	2023-10-25	да 
186	8	186	8	4	30	4530	2023-10-25	2023-10-26	нет
187	7	187	8	1	30	1230	2023-10-26	2023-10-27	нет
188	2	188	8	4	0	4400	2023-10-27	2023-10-28	нет
189	8	189	8	7	30	7830	2023-10-28	2023-10-29	да 
190	2	190	8	7	30	7830	2023-10-29	2023-10-30	да 
191	6	191	8	7	30	7830	2023-10-30	2023-10-31	да 
192	9	192	8	8	60	9060	2023-10-31	2023-11-01	да 
193	1	193	8	10	60	11260	2023-11-01	2023-11-02	да 
194	9	194	8	12	30	13330	2023-11-02	2023-11-03	да 
195	1	195	8	9	30	10030	2023-11-03	2023-11-04	да 
196	7	196	8	7	30	7830	2023-11-04	2023-11-05	да 
197	4	197	8	8	30	8930	2023-11-05	2023-11-06	да 
198	3	198	8	12	30	13330	2023-11-06	2023-11-07	да 
199	2	199	8	3	30	3430	2023-11-07	2023-11-08	нет
200	4	200	8	1	0	1100	2023-11-08	2023-11-09	нет
201	7	201	8	5	60	5760	2023-11-09	2023-11-10	нет
202	10	202	8	10	30	11130	2023-11-10	2023-11-11	да 
203	8	203	8	4	30	4530	2023-11-11	2023-11-12	нет
204	10	204	8	3	60	3560	2023-11-12	2023-11-13	нет
205	8	205	8	1	30	1230	2023-11-13	2023-11-14	нет
206	5	206	8	4	60	4660	2023-11-14	2023-11-15	нет
207	9	207	8	11	30	12230	2023-11-15	2023-11-16	да 
208	10	208	8	3	30	3430	2023-11-16	2023-11-17	нет
209	1	209	8	11	30	12230	2023-11-17	2023-11-18	да 
210	1	210	8	8	60	9060	2023-11-18	2023-11-19	да 
211	1	211	8	2	60	2460	2023-11-19	2023-11-20	нет
212	7	212	8	4	0	4400	2023-11-20	2023-11-21	нет
213	10	213	8	7	30	7830	2023-11-21	2023-11-22	да 
214	9	214	8	6	30	6730	2023-11-22	2023-11-23	нет
215	1	215	8	12	30	13330	2023-11-23	2023-11-24	да 
216	10	216	8	5	30	5630	2023-11-24	2023-11-25	нет
217	9	217	8	9	30	10030	2023-11-25	2023-11-26	да 
218	1	218	8	12	60	13460	2023-11-26	2023-11-27	да 
219	4	219	8	11	30	12230	2023-11-27	2023-11-28	да 
220	2	220	8	11	60	12360	2023-11-28	2023-11-29	да 
221	10	221	8	10	30	11130	2023-11-29	2023-11-30	да 
222	8	222	8	11	30	12230	2023-11-30	2023-12-01	да 
223	5	223	8	6	30	6730	2023-12-01	2023-12-02	да 
224	5	224	8	6	0	6600	2023-12-02	2023-12-03	да 
225	6	225	8	11	30	12230	2023-12-03	2023-12-04	да 
226	6	226	8	6	60	6860	2023-12-04	2023-12-05	да 
227	2	227	8	7	30	7830	2023-12-05	2023-12-06	да 
228	4	228	8	11	60	12360	2023-12-06	2023-12-07	да 
229	4	229	8	1	30	1230	2023-12-07	2023-12-08	нет
230	5	230	8	5	30	5630	2023-12-08	2023-12-09	нет
231	3	231	8	5	60	5760	2023-12-09	2023-12-10	нет
232	1	232	8	3	30	3430	2023-12-10	2023-12-11	нет
233	3	233	8	6	60	6860	2023-12-11	2023-12-12	да 
234	8	234	8	2	60	2460	2023-12-12	2023-12-13	нет
235	3	235	8	1	30	1230	2023-12-13	2023-12-14	нет
236	7	236	8	6	60	6860	2023-12-14	2023-12-15	да 
237	6	237	8	9	30	10030	2023-12-15	2023-12-16	да 
238	8	238	8	11	30	12230	2023-12-16	2023-12-17	да 
239	1	239	8	2	30	2330	2023-12-17	2023-12-18	нет
240	1	240	8	11	30	12230	2023-12-18	2023-12-19	да 
241	1	241	8	2	0	2200	2023-12-19	2023-12-20	нет
242	5	242	8	12	30	13330	2023-12-20	2023-12-21	да 
243	7	243	8	5	30	5630	2023-12-21	2023-12-22	нет
244	10	244	8	1	60	1360	2023-12-22	2023-12-23	нет
245	2	245	8	8	60	9060	2023-12-23	2023-12-24	да 
246	1	246	8	12	0	13200	2023-12-24	2023-12-25	да 
247	9	247	8	9	30	10030	2023-12-25	2023-12-26	да 
248	6	248	8	8	30	8930	2023-12-26	2023-12-27	да 
249	2	249	8	7	30	7830	2023-12-27	2023-12-28	да 
250	5	250	8	11	30	12230	2023-12-28	2023-12-29	да 
251	2	251	8	4	60	4660	2023-12-29	2023-12-30	нет
252	4	252	8	9	30	10030	2023-12-30	2023-12-31	да 
253	10	253	8	12	60	13460	2023-12-31	2024-01-01	да 
254	10	254	8	12	30	13330	2024-01-01	2024-01-02	да 
255	6	255	8	9	60	10160	2024-01-02	2024-01-03	да 
256	3	256	8	4	30	4530	2024-01-03	2024-01-04	нет
257	1	257	8	10	0	11000	2024-01-04	2024-01-05	да 
258	2	258	8	4	60	4660	2024-01-05	2024-01-06	нет
259	6	259	8	3	30	3430	2024-01-06	2024-01-07	нет
260	3	260	8	11	60	12360	2024-01-07	2024-01-08	да 
261	5	261	8	8	30	8930	2024-01-08	2024-01-09	да 
262	2	262	9	11	30	13320	2024-01-09	2024-01-10	да 
263	6	263	9	3	30	3720	2024-01-10	2024-01-11	нет
264	2	264	9	11	30	13320	2024-01-11	2024-01-12	да 
265	4	265	9	9	60	11040	2024-01-12	2024-01-13	да 
266	8	266	9	10	30	12120	2024-01-13	2024-01-14	да 
267	5	267	9	3	60	3840	2024-01-14	2024-01-15	нет
268	9	268	9	9	30	10920	2024-01-15	2024-01-16	да 
269	9	269	9	6	60	7440	2024-01-16	2024-01-17	да 
270	3	270	9	12	30	14520	2024-01-17	2024-01-18	да 
271	8	271	9	8	0	9600	2024-01-18	2024-01-19	да 
272	2	272	9	6	30	7320	2024-01-19	2024-01-20	да 
273	5	273	9	6	30	7320	2024-01-20	2024-01-21	да 
274	7	274	9	7	30	8520	2024-01-21	2024-01-22	да 
275	1	275	9	12	30	14520	2024-01-22	2024-01-23	да 
276	9	276	9	2	30	2520	2024-01-23	2024-01-24	нет
277	2	277	9	5	60	6240	2024-01-24	2024-01-25	да 
278	6	278	9	7	60	8640	2024-01-25	2024-01-26	да 
279	7	279	9	2	60	2640	2024-01-26	2024-01-27	нет
280	3	280	9	1	30	1320	2024-01-27	2024-01-28	нет
281	7	281	9	4	60	5040	2024-01-28	2024-01-29	да 
282	3	282	9	7	30	8520	2024-01-29	2024-01-30	да 
283	8	283	9	1	30	1320	2024-01-30	2024-01-31	нет
284	10	284	9	6	60	7440	2024-01-31	2024-02-01	да 
285	8	285	9	2	60	2640	2024-02-01	2024-02-02	нет
286	9	286	9	11	30	13320	2024-02-02	2024-02-03	да 
287	9	287	9	9	30	10920	2024-02-03	2024-02-04	да 
288	1	288	9	3	0	3600	2024-02-04	2024-02-05	нет
289	3	289	9	4	30	4920	2024-02-05	2024-02-06	да 
290	2	290	9	1	30	1320	2024-02-06	2024-02-07	нет
291	5	291	9	2	30	2520	2024-02-07	2024-02-08	нет
292	3	292	9	12	60	14640	2024-02-08	2024-02-09	да 
293	2	293	9	4	60	5040	2024-02-09	2024-02-10	да 
294	5	294	9	9	30	10920	2024-02-10	2024-02-11	да 
295	3	295	9	10	30	12120	2024-02-11	2024-02-12	да 
296	10	296	9	10	30	12120	2024-02-12	2024-02-13	да 
297	9	297	9	1	30	1320	2024-02-13	2024-02-14	нет
298	7	298	9	6	30	7320	2024-02-14	2024-02-15	да 
299	5	299	9	2	30	2520	2024-02-15	2024-02-16	нет
300	1	300	9	7	0	8400	2024-02-16	2024-02-17	да 
301	9	301	9	7	60	8640	2024-02-17	2024-02-18	да 
302	3	302	9	9	30	10920	2024-02-18	2024-02-19	да 
303	7	303	9	9	30	10920	2024-02-19	2024-02-20	да 
304	2	304	9	11	60	13440	2024-02-20	2024-02-21	да 
305	1	305	9	5	30	6120	2024-02-21	2024-02-22	да 
306	7	306	9	6	60	7440	2024-02-22	2024-02-23	да 
307	7	307	9	1	30	1320	2024-02-23	2024-02-24	нет
308	8	308	9	10	30	12120	2024-02-24	2024-02-25	да 
309	9	309	9	2	30	2520	2024-02-25	2024-02-26	нет
310	1	310	9	2	60	2640	2024-02-26	2024-02-27	нет
311	1	311	9	7	60	8640	2024-02-27	2024-02-28	да 
312	7	312	9	3	0	3600	2024-02-28	2024-02-29	да 
313	4	313	9	3	30	3720	2024-02-29	2024-03-01	да 
314	8	314	9	5	30	6120	2024-03-01	2024-03-02	да 
315	2	315	9	1	30	1320	2024-03-02	2024-03-03	нет
316	4	316	9	6	30	7320	2024-03-03	2024-03-04	да 
317	5	317	9	4	30	4920	2024-03-04	2024-03-05	да 
318	4	318	9	5	60	6240	2024-03-05	2024-03-06	да 
319	10	319	9	1	30	1320	2024-03-06	2024-03-07	нет
320	4	320	9	4	60	5040	2024-03-07	2024-03-08	да 
321	3	321	9	5	30	6120	2024-03-08	2024-03-09	да 
322	5	322	9	1	30	1320	2024-03-09	2024-03-10	нет
323	6	323	9	3	30	3720	2024-03-10	2024-03-11	да 
324	8	324	9	10	0	12000	2024-03-11	2024-03-12	да 
325	3	325	9	12	30	14520	2024-03-12	2024-03-13	да 
326	4	326	9	11	60	13440	2024-03-13	2024-03-14	да 
327	2	327	9	8	30	9720	2024-03-14	2024-03-15	да 
328	2	328	9	10	60	12240	2024-03-15	2024-03-16	да 
329	1	329	9	1	30	1320	2024-03-16	2024-03-17	нет
330	4	330	9	12	30	14520	2024-03-17	2024-03-18	да 
331	10	331	9	8	60	9840	2024-03-18	2024-03-19	да 
332	4	332	9	1	30	1320	2024-03-19	2024-03-20	нет
333	8	333	9	9	60	11040	2024-03-20	2024-03-21	да 
334	1	334	9	2	60	2640	2024-03-21	2024-03-22	нет
335	2	335	9	1	30	1320	2024-03-22	2024-03-23	нет
336	8	336	9	11	60	13440	2024-03-23	2024-03-24	да 
337	8	337	9	9	30	10920	2024-03-24	2024-03-25	да 
338	4	338	9	4	30	4920	2024-03-25	2024-03-26	да 
339	2	339	9	9	30	10920	2024-03-26	2024-03-27	да 
340	1	340	9	11	30	13320	2024-03-27	2024-03-28	да 
341	2	341	9	6	0	7200	2024-03-28	2024-03-29	да 
342	4	342	9	5	30	6120	2024-03-29	2024-03-30	да 
343	9	343	9	10	30	12120	2024-03-30	2024-03-31	да 
344	2	344	9	3	60	3840	2024-03-31	2024-04-01	да 
345	9	345	9	10	60	12240	2024-04-01	2024-04-02	да 
346	8	346	9	9	0	10800	2024-04-02	2024-04-03	да 
347	8	347	9	12	30	14520	2024-04-03	2024-04-04	да 
348	1	348	9	12	30	14520	2024-04-04	2024-04-05	да 
349	4	349	9	9	30	10920	2024-04-05	2024-04-06	да 
350	3	350	9	12	30	14520	2024-04-06	2024-04-07	да 
351	2	351	9	12	60	14640	2024-04-07	2024-04-08	да 
352	3	352	9	8	30	9720	2024-04-08	2024-04-09	да 
353	9	353	9	2	60	2640	2024-04-09	2024-04-10	да 
354	5	354	10	1	30	1430	2024-04-10	2024-04-11	нет
355	1	355	10	1	60	1560	2024-04-11	2024-04-12	нет
356	1	356	10	2	30	2730	2024-04-12	2024-04-13	да 
357	2	357	10	6	0	7800	2024-04-13	2024-04-14	да 
358	5	358	10	1	60	1560	2024-04-14	2024-04-15	нет
359	1	359	10	4	30	5330	2024-04-15	2024-04-16	да 
360	10	360	10	9	60	11960	2024-04-16	2024-04-17	да 
361	1	361	10	10	30	13130	2024-04-17	2024-04-18	да 
362	4	362	10	10	30	13130	2024-04-18	2024-04-19	да 
363	3	363	10	3	30	4030	2024-04-19	2024-04-20	да 
364	3	364	10	9	30	11830	2024-04-20	2024-04-21	да 
365	9	365	10	12	60	15860	2024-04-21	2024-04-22	да 
366	10	366	10	8	30	10530	2024-04-22	2024-04-23	да 
367	5	367	10	8	60	10660	2024-04-23	2024-04-24	да 
368	8	368	10	12	30	15730	2024-04-24	2024-04-25	да 
369	2	369	10	4	60	5460	2024-04-25	2024-04-26	да 
370	7	370	10	8	30	10530	2024-04-26	2024-04-27	да 
371	7	371	10	9	0	11700	2024-04-27	2024-04-28	да 
372	9	372	10	11	30	14430	2024-04-28	2024-04-29	да 
373	9	373	10	3	30	4030	2024-04-29	2024-04-30	да 
374	6	374	10	3	30	4030	2024-04-30	2024-05-01	да 
375	6	375	10	11	30	14430	2024-05-01	2024-05-02	да 
376	6	376	10	1	30	1430	2024-05-02	2024-05-03	да 
377	3	377	10	1	60	1560	2024-05-03	2024-05-04	да 
378	1	378	10	11	60	14560	2024-05-04	2024-05-05	да 
379	10	379	10	11	60	14560	2024-05-05	2024-05-06	да 
380	1	380	10	12	30	15730	2024-05-06	2024-05-07	да 
381	7	381	10	12	60	15860	2024-05-07	2024-05-08	да 
382	7	382	10	9	30	11830	2024-05-08	2024-05-09	да 
383	6	383	10	8	30	10530	2024-05-09	2024-05-10	да 
384	3	384	10	3	60	4160	2024-05-10	2024-05-11	да 
385	5	385	10	4	60	5460	2024-05-11	2024-05-12	да 
386	3	386	10	3	30	4030	2024-05-12	2024-05-13	да 
387	4	387	10	8	30	10530	2024-05-13	2024-05-14	да 
388	7	388	10	5	0	6500	2024-05-14	2024-05-15	да 
389	3	389	10	12	30	15730	2024-05-15	2024-05-16	да 
390	2	390	10	8	30	10530	2024-05-16	2024-05-17	да 
391	7	391	10	1	30	1430	2024-05-17	2024-05-18	да 
392	1	392	10	8	60	10660	2024-05-18	2024-05-19	да 
393	2	393	10	9	60	11960	2024-05-19	2024-05-20	да 
394	8	394	10	5	30	6630	2024-05-20	2024-05-21	да 
395	3	395	10	1	30	1430	2024-05-21	2024-05-22	да 
396	5	396	10	1	30	1430	2024-05-22	2024-05-23	да 
397	2	397	10	11	30	14430	2024-05-23	2024-05-24	да 
398	6	398	10	7	30	9230	2024-05-24	2024-05-25	да 
399	3	399	10	9	30	11830	2024-05-25	2024-05-26	да 
400	10	400	10	1	0	1300	2024-05-26	2024-05-27	да 
\.


                                                                                                                                                                                        4921.dat                                                                                            0000600 0004000 0002000 00000005616 14630037536 0014270 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        30	1	1
13	2	2
20	3	3
3	4	4
4	5	5
22	6	6
13	7	7
13	8	8
13	9	9
20	10	10
13	11	11
14	12	12
20	13	13
14	14	14
13	15	15
4	16	16
20	17	17
30	18	18
20	20	19
30	21	20
20	22	21
20	24	22
13	25	23
22	26	24
20	28	25
30	29	26
14	30	27
13	32	28
3	34	29
30	35	30
3	36	31
14	38	32
14	39	33
3	40	34
4	41	35
13	42	36
30	43	37
13	44	38
14	45	39
20	46	40
4	47	41
22	49	42
20	50	43
3	51	44
14	52	45
22	53	46
13	54	47
30	55	48
14	56	49
30	57	50
30	58	51
14	60	52
14	62	53
22	63	54
20	65	55
3	66	56
20	68	57
3	70	58
4	71	59
30	72	60
3	77	61
22	78	62
3	79	63
3	80	64
20	81	65
20	82	66
20	83	67
13	84	68
4	86	69
20	87	70
3	90	71
20	94	72
14	95	73
22	97	74
30	98	75
3	99	76
4	100	77
22	101	78
13	103	79
4	104	80
20	106	81
3	107	82
4	108	83
22	109	84
3	110	85
3	111	86
13	112	87
20	114	88
4	115	89
14	117	90
13	118	91
13	119	92
22	120	93
22	123	94
14	124	95
22	125	96
13	126	97
22	127	98
22	128	99
30	129	100
30	130	101
14	131	102
22	132	103
14	133	104
30	134	105
14	136	106
30	137	107
22	138	108
30	139	109
3	142	110
14	143	111
22	144	112
20	145	113
14	146	114
3	149	115
3	150	116
20	151	117
14	154	118
20	155	119
20	156	120
14	157	121
20	158	122
22	160	123
13	161	124
4	162	125
13	163	126
30	164	127
30	165	128
13	166	129
13	168	130
14	169	131
4	170	132
22	171	133
30	172	134
14	173	135
30	174	136
30	175	137
22	176	138
14	178	139
30	179	140
13	180	141
13	181	142
3	184	143
14	186	144
4	187	145
13	189	146
22	190	147
14	191	148
22	192	149
30	193	150
30	194	151
22	197	152
20	199	153
22	200	154
20	201	155
4	204	156
22	205	157
3	206	158
20	209	159
4	210	160
30	212	161
3	213	162
20	216	163
3	222	164
14	223	165
20	224	166
3	225	167
14	226	168
30	228	169
14	229	170
3	231	171
22	232	172
20	233	173
22	234	174
30	236	175
3	240	176
30	241	177
13	243	178
22	244	179
4	245	180
30	246	181
4	247	182
3	248	183
22	250	184
14	251	185
14	252	186
14	253	187
30	254	188
30	255	189
14	256	190
22	257	191
3	258	192
14	261	193
20	262	194
20	263	195
13	266	196
3	267	197
3	268	198
3	269	199
30	272	200
20	273	201
13	274	202
20	275	203
13	276	204
14	277	205
3	279	206
22	280	207
14	281	208
20	282	209
14	283	210
14	284	211
13	285	212
30	287	213
22	288	214
22	289	215
22	290	216
13	291	217
13	292	218
13	294	219
22	297	220
13	298	221
13	300	222
14	301	223
14	302	224
22	303	225
3	304	226
20	305	227
20	307	228
22	308	229
3	309	230
13	310	231
22	311	232
30	312	233
22	314	234
14	315	235
4	316	236
22	317	237
14	319	238
14	320	239
22	323	240
4	324	241
4	325	242
14	331	243
14	332	244
30	333	245
20	334	246
30	335	247
22	336	248
3	337	249
20	338	250
4	339	251
13	340	252
3	341	253
13	342	254
22	343	255
20	344	256
30	346	257
4	347	258
3	349	259
20	350	260
30	352	261
13	353	262
22	355	263
22	357	264
22	359	265
14	360	266
22	363	267
4	364	268
22	366	269
4	368	270
13	371	271
3	372	272
13	373	273
22	375	274
30	376	275
14	377	276
14	378	277
20	379	278
22	381	279
22	382	280
3	383	281
20	384	282
30	386	283
30	388	284
14	389	285
4	390	286
20	393	287
30	394	288
4	395	289
4	396	290
14	398	291
3	399	292
\.


                                                                                                                  4916.dat                                                                                            0000600 0004000 0002000 00000001472 14630037536 0014270 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	Протеиновый батончик	100
2	Витаминный напиток  	50
3	Энергетический гель 	80
4	Белковый коктейль   	120
5	Минеральная вода    	30
6	Спортивные таблетки 	150
7	Гейнер              	200
8	Витаминный комплекс 	90
9	Сухофрукты          	70
10	Энергетический бар  	60
11	Белковый кокос      	110
12	Миндаль             	40
13	Спортивная каша     	85
14	Омега-3капсулы      	75
15	Фруктовый коктейль  	65
16	Электролиты         	55
17	Банановые чипсы     	45
18	Желатиновые конфеты 	95
19	Овсяные батончики   	110
20	Фисташки            	50
\.


                                                                                                                                                                                                      4917.dat                                                                                            0000600 0004000 0002000 00000002030 14630037536 0014260 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	1	52
2	1	84
3	1	97
4	1	41
5	1	12
6	1	53
7	1	10
8	1	20
9	1	58
10	1	53
11	1	20
12	1	89
13	1	19
14	1	35
10	2	70
11	2	67
12	2	32
13	2	56
14	2	31
15	2	43
16	2	23
17	2	38
18	2	98
19	2	23
20	2	25
4	3	54
5	3	73
6	3	21
7	3	85
8	3	100
9	3	15
10	3	28
11	3	13
12	3	47
13	3	21
14	3	93
1	4	71
2	4	60
3	4	12
4	4	18
5	4	33
6	4	72
7	4	98
8	4	70
9	4	52
10	4	83
11	4	20
12	4	59
13	4	71
14	4	14
15	4	14
16	4	65
17	4	94
18	4	55
19	4	95
20	4	48
5	5	14
6	5	93
7	5	94
8	5	20
9	5	92
10	5	67
11	5	66
12	5	44
13	5	90
14	5	88
15	5	25
16	5	61
17	5	96
18	5	87
19	5	19
1	6	44
2	6	75
3	6	25
4	6	60
5	6	40
6	6	21
7	6	62
8	6	61
9	6	35
10	6	35
11	6	77
12	6	39
13	6	89
1	7	41
2	7	35
3	7	15
4	7	94
5	7	79
6	7	59
7	7	97
8	7	88
9	7	10
10	7	10
11	7	47
12	7	97
13	7	97
14	7	39
15	7	48
16	7	28
17	7	20
18	7	99
14	8	25
15	8	41
16	8	28
17	8	35
18	8	82
19	8	13
20	8	15
4	9	23
5	9	32
6	9	69
7	9	36
8	9	53
9	9	20
10	9	46
11	9	12
12	9	94
13	9	59
14	9	86
15	9	60
16	9	66
3	10	38
4	10	97
5	10	15
6	10	35
7	10	91
8	10	32
9	10	31
10	10	97
11	10	12
12	10	36
13	10	86
14	10	90
15	10	10
16	10	60
\.


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        4910.dat                                                                                            0000600 0004000 0002000 00000000620 14630037536 0014254 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	700	100	2022-01-01	2022-04-01
2	700	100	2022-04-02	2022-07-02
3	800	120	2022-07-03	2022-10-03
4	900	150	2022-10-04	2023-01-04
5	1000	140	2023-01-05	2023-04-05
6	1100	150	2023-04-06	2023-07-06
7	1000	130	2023-07-07	2023-10-07
8	1100	130	2023-10-08	2024-01-08
9	1200	120	2024-01-09	2024-04-09
10	1300	130	2024-04-10	2024-07-10
11	1200	110	2024-07-11	2024-10-11
12	1000	120	2024-10-12	2025-01-12
\.


                                                                                                                4922.dat                                                                                            0000600 0004000 0002000 00000014734 14630037536 0014272 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	Понедельник         	1	09:00:00
2	Понедельник         	2	10:00:00
3	Понедельник         	3	11:00:00
4	Понедельник         	4	12:00:00
5	Понедельник         	5	13:00:00
6	Понедельник         	6	14:00:00
7	Понедельник         	7	15:00:00
8	Понедельник         	8	16:00:00
9	Понедельник         	9	17:00:00
10	Понедельник         	10	18:00:00
11	Понедельник         	11	19:00:00
12	Понедельник         	12	20:00:00
13	Понедельник         	13	09:00:00
14	Понедельник         	14	10:00:00
15	Понедельник         	15	11:00:00
16	Понедельник         	16	12:00:00
17	Понедельник         	17	13:00:00
18	Понедельник         	18	14:00:00
19	Понедельник         	19	15:00:00
20	Понедельник         	20	16:00:00
21	Понедельник         	21	17:00:00
22	Вторник             	22	09:00:00
23	Вторник             	23	10:00:00
24	Вторник             	24	11:00:00
25	Вторник             	25	12:00:00
26	Вторник             	26	13:00:00
27	Вторник             	27	14:00:00
28	Вторник             	28	15:00:00
29	Вторник             	29	16:00:00
30	Вторник             	30	17:00:00
31	Вторник             	31	18:00:00
32	Вторник             	32	19:00:00
33	Вторник             	33	20:00:00
34	Вторник             	34	09:00:00
35	Вторник             	35	10:00:00
36	Вторник             	36	11:00:00
37	Вторник             	37	12:00:00
38	Вторник             	38	13:00:00
39	Вторник             	39	14:00:00
40	Вторник             	40	15:00:00
41	Вторник             	41	16:00:00
42	Вторник             	42	17:00:00
43	Среда               	43	09:00:00
44	Среда               	44	10:00:00
45	Среда               	45	11:00:00
46	Среда               	46	12:00:00
47	Среда               	47	13:00:00
48	Среда               	48	14:00:00
49	Среда               	49	15:00:00
50	Среда               	50	16:00:00
51	Среда               	1	17:00:00
52	Среда               	2	18:00:00
53	Среда               	3	19:00:00
54	Среда               	4	20:00:00
55	Среда               	5	09:00:00
56	Среда               	6	10:00:00
57	Среда               	7	11:00:00
58	Среда               	8	12:00:00
59	Среда               	9	13:00:00
60	Среда               	10	14:00:00
61	Среда               	11	15:00:00
62	Среда               	12	16:00:00
63	Среда               	13	17:00:00
64	Четверг             	14	09:00:00
65	Четверг             	15	10:00:00
66	Четверг             	16	11:00:00
67	Четверг             	17	12:00:00
68	Четверг             	18	13:00:00
69	Четверг             	19	14:00:00
70	Четверг             	20	15:00:00
71	Четверг             	21	16:00:00
72	Четверг             	22	17:00:00
73	Четверг             	23	18:00:00
74	Четверг             	24	19:00:00
75	Четверг             	25	09:00:00
76	Четверг             	26	10:00:00
77	Четверг             	27	11:00:00
78	Четверг             	28	12:00:00
79	Четверг             	29	13:00:00
80	Четверг             	30	14:00:00
81	Четверг             	31	15:00:00
82	Четверг             	32	16:00:00
83	Пятница             	33	17:00:00
84	Пятница             	34	09:00:00
85	Пятница             	35	10:00:00
86	Пятница             	36	11:00:00
87	Пятница             	37	12:00:00
88	Пятница             	38	13:00:00
89	Пятница             	39	14:00:00
90	Пятница             	40	15:00:00
91	Пятница             	41	16:00:00
92	Пятница             	42	17:00:00
93	Пятница             	43	18:00:00
94	Пятница             	44	09:00:00
95	Пятница             	45	10:00:00
96	Пятница             	46	11:00:00
97	Пятница             	47	12:00:00
98	Пятница             	48	13:00:00
99	Пятница             	49	14:00:00
100	Пятница             	50	15:00:00
101	Пятница             	1	16:00:00
102	Пятница             	2	17:00:00
103	Пятница             	3	18:00:00
104	Пятница             	4	19:00:00
105	Суббота             	5	09:00:00
106	Суббота             	6	10:00:00
107	Суббота             	7	11:00:00
108	Суббота             	8	12:00:00
109	Суббота             	9	13:00:00
110	Суббота             	10	14:00:00
111	Суббота             	11	15:00:00
112	Суббота             	12	16:00:00
113	Суббота             	13	17:00:00
114	Суббота             	14	09:00:00
115	Суббота             	15	10:00:00
116	Суббота             	16	11:00:00
117	Суббота             	17	12:00:00
118	Суббота             	18	13:00:00
119	Суббота             	19	14:00:00
120	Суббота             	20	15:00:00
121	Суббота             	21	16:00:00
122	Суббота             	22	17:00:00
123	Суббота             	23	18:00:00
124	Воскресенье         	24	09:00:00
125	Воскресенье         	25	10:00:00
126	Воскресенье         	26	11:00:00
127	Воскресенье         	27	12:00:00
128	Воскресенье         	28	13:00:00
129	Воскресенье         	29	14:00:00
130	Воскресенье         	30	15:00:00
131	Воскресенье         	31	16:00:00
132	Воскресенье         	32	17:00:00
133	Воскресенье         	33	18:00:00
134	Воскресенье         	34	19:00:00
135	Воскресенье         	35	20:00:00
136	Воскресенье         	36	21:00:00
137	Воскресенье         	37	22:00:00
138	Воскресенье         	38	09:00:00
139	Воскресенье         	39	10:00:00
140	Воскресенье         	40	11:00:00
141	Воскресенье         	41	12:00:00
142	Воскресенье         	42	13:00:00
143	Воскресенье         	43	14:00:00
144	Воскресенье         	44	15:00:00
145	Воскресенье         	45	16:00:00
146	Воскресенье         	46	17:00:00
147	Воскресенье         	47	18:00:00
148	Воскресенье         	48	19:00:00
149	Воскресенье         	49	20:00:00
150	Воскресенье         	50	21:00:00
\.


                                    4924.dat                                                                                            0000600 0004000 0002000 00000031615 14630037536 0014271 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	1	Понедельник         	09:00:00
2	2	Понедельник         	10:00:00
3	3	Понедельник         	11:00:00
4	4	Понедельник         	12:00:00
5	5	Понедельник         	13:00:00
6	6	Понедельник         	14:00:00
7	7	Понедельник         	15:00:00
8	8	Понедельник         	16:00:00
9	9	Понедельник         	17:00:00
10	10	Понедельник         	18:00:00
11	11	Понедельник         	19:00:00
12	12	Понедельник         	20:00:00
13	13	Понедельник         	09:00:00
14	14	Понедельник         	10:00:00
15	15	Понедельник         	11:00:00
16	16	Понедельник         	12:00:00
17	17	Понедельник         	13:00:00
18	18	Понедельник         	14:00:00
19	19	Понедельник         	15:00:00
20	20	Понедельник         	16:00:00
21	21	Понедельник         	17:00:00
22	22	Вторник             	09:00:00
23	23	Вторник             	10:00:00
24	24	Вторник             	11:00:00
25	25	Вторник             	12:00:00
26	26	Вторник             	13:00:00
27	27	Вторник             	14:00:00
28	28	Вторник             	15:00:00
29	29	Вторник             	16:00:00
30	30	Вторник             	17:00:00
31	31	Вторник             	18:00:00
32	32	Вторник             	19:00:00
33	33	Вторник             	20:00:00
34	34	Вторник             	09:00:00
35	35	Вторник             	10:00:00
36	36	Вторник             	11:00:00
37	37	Вторник             	12:00:00
38	38	Вторник             	13:00:00
39	39	Вторник             	14:00:00
40	40	Вторник             	15:00:00
41	41	Вторник             	16:00:00
42	42	Вторник             	17:00:00
43	43	Среда               	09:00:00
44	44	Среда               	10:00:00
45	45	Среда               	11:00:00
46	46	Среда               	12:00:00
47	47	Среда               	13:00:00
48	48	Среда               	14:00:00
49	49	Среда               	15:00:00
50	50	Среда               	16:00:00
51	51	Среда               	17:00:00
52	52	Среда               	18:00:00
53	53	Среда               	19:00:00
54	54	Среда               	20:00:00
55	55	Среда               	09:00:00
56	56	Среда               	10:00:00
57	57	Среда               	11:00:00
58	58	Среда               	12:00:00
59	59	Среда               	13:00:00
60	60	Среда               	14:00:00
61	61	Среда               	15:00:00
62	62	Среда               	16:00:00
63	63	Среда               	17:00:00
64	64	Четверг             	09:00:00
65	65	Четверг             	10:00:00
66	66	Четверг             	11:00:00
67	67	Четверг             	12:00:00
68	68	Четверг             	13:00:00
69	69	Четверг             	14:00:00
70	70	Четверг             	15:00:00
71	71	Четверг             	16:00:00
72	72	Четверг             	17:00:00
73	73	Четверг             	18:00:00
74	74	Четверг             	19:00:00
75	75	Четверг             	09:00:00
76	76	Четверг             	10:00:00
77	77	Четверг             	11:00:00
78	78	Четверг             	12:00:00
79	79	Четверг             	13:00:00
80	80	Четверг             	14:00:00
81	81	Четверг             	15:00:00
82	82	Четверг             	16:00:00
83	83	Пятница             	17:00:00
84	84	Пятница             	09:00:00
85	85	Пятница             	10:00:00
86	86	Пятница             	11:00:00
87	87	Пятница             	12:00:00
88	88	Пятница             	13:00:00
89	89	Пятница             	14:00:00
90	90	Пятница             	15:00:00
91	91	Пятница             	16:00:00
92	92	Пятница             	17:00:00
93	93	Пятница             	18:00:00
94	94	Пятница             	09:00:00
95	95	Пятница             	10:00:00
96	96	Пятница             	11:00:00
97	97	Пятница             	12:00:00
98	98	Пятница             	13:00:00
99	99	Пятница             	14:00:00
100	100	Пятница             	15:00:00
101	101	Пятница             	16:00:00
102	102	Пятница             	17:00:00
103	103	Пятница             	18:00:00
104	104	Пятница             	19:00:00
105	105	Суббота             	09:00:00
106	106	Суббота             	10:00:00
107	107	Суббота             	11:00:00
108	108	Суббота             	12:00:00
109	109	Суббота             	13:00:00
110	110	Суббота             	14:00:00
111	111	Суббота             	15:00:00
112	112	Суббота             	16:00:00
113	113	Суббота             	17:00:00
114	114	Суббота             	09:00:00
115	115	Суббота             	10:00:00
116	116	Суббота             	11:00:00
117	117	Суббота             	12:00:00
118	118	Суббота             	13:00:00
119	119	Суббота             	14:00:00
120	120	Суббота             	15:00:00
121	121	Суббота             	16:00:00
122	122	Суббота             	17:00:00
123	123	Суббота             	18:00:00
124	124	Воскресенье         	09:00:00
125	125	Воскресенье         	10:00:00
126	126	Воскресенье         	11:00:00
127	127	Воскресенье         	12:00:00
128	128	Воскресенье         	13:00:00
129	129	Воскресенье         	14:00:00
130	130	Воскресенье         	15:00:00
131	131	Воскресенье         	16:00:00
132	132	Воскресенье         	17:00:00
133	133	Воскресенье         	18:00:00
134	134	Воскресенье         	19:00:00
135	135	Воскресенье         	20:00:00
136	136	Воскресенье         	21:00:00
137	137	Воскресенье         	22:00:00
138	138	Воскресенье         	09:00:00
139	139	Воскресенье         	10:00:00
140	140	Воскресенье         	11:00:00
141	141	Воскресенье         	12:00:00
142	142	Воскресенье         	13:00:00
143	143	Воскресенье         	14:00:00
144	144	Воскресенье         	15:00:00
145	145	Воскресенье         	16:00:00
146	146	Воскресенье         	17:00:00
147	147	Воскресенье         	18:00:00
148	148	Воскресенье         	19:00:00
149	149	Воскресенье         	20:00:00
150	150	Воскресенье         	21:00:00
151	151	Понедельник         	09:00:00
152	152	Понедельник         	10:00:00
153	153	Понедельник         	11:00:00
154	154	Понедельник         	12:00:00
155	155	Понедельник         	13:00:00
156	156	Понедельник         	14:00:00
157	157	Понедельник         	15:00:00
158	158	Понедельник         	16:00:00
159	159	Понедельник         	17:00:00
160	160	Понедельник         	18:00:00
161	161	Понедельник         	19:00:00
162	162	Понедельник         	20:00:00
163	163	Понедельник         	09:00:00
164	164	Понедельник         	10:00:00
165	165	Понедельник         	11:00:00
166	166	Понедельник         	12:00:00
167	167	Понедельник         	13:00:00
168	168	Понедельник         	14:00:00
169	169	Понедельник         	15:00:00
170	170	Понедельник         	16:00:00
171	171	Понедельник         	17:00:00
172	172	Вторник             	09:00:00
173	173	Вторник             	10:00:00
174	174	Вторник             	11:00:00
175	175	Вторник             	12:00:00
176	176	Вторник             	13:00:00
177	177	Вторник             	14:00:00
178	178	Вторник             	15:00:00
179	179	Вторник             	16:00:00
180	180	Вторник             	17:00:00
181	181	Вторник             	18:00:00
182	182	Вторник             	19:00:00
183	183	Вторник             	20:00:00
184	184	Вторник             	09:00:00
185	185	Вторник             	10:00:00
186	186	Вторник             	11:00:00
187	187	Вторник             	12:00:00
188	188	Вторник             	13:00:00
189	189	Вторник             	14:00:00
190	190	Вторник             	15:00:00
191	191	Вторник             	16:00:00
192	192	Вторник             	17:00:00
193	193	Среда               	09:00:00
194	194	Среда               	10:00:00
195	195	Среда               	11:00:00
196	196	Среда               	12:00:00
197	197	Среда               	13:00:00
198	198	Среда               	14:00:00
199	199	Среда               	15:00:00
200	200	Среда               	16:00:00
201	201	Среда               	17:00:00
202	202	Среда               	18:00:00
203	203	Среда               	19:00:00
204	204	Среда               	20:00:00
205	205	Среда               	09:00:00
206	206	Среда               	10:00:00
207	207	Среда               	11:00:00
208	208	Среда               	12:00:00
209	209	Среда               	13:00:00
210	210	Среда               	14:00:00
211	211	Среда               	15:00:00
212	212	Среда               	16:00:00
213	213	Среда               	17:00:00
214	214	Четверг             	09:00:00
215	215	Четверг             	10:00:00
216	216	Четверг             	11:00:00
217	217	Четверг             	12:00:00
218	218	Четверг             	13:00:00
219	219	Четверг             	14:00:00
220	220	Четверг             	15:00:00
221	221	Четверг             	16:00:00
222	222	Четверг             	17:00:00
223	223	Четверг             	18:00:00
224	224	Четверг             	19:00:00
225	225	Четверг             	09:00:00
226	226	Четверг             	10:00:00
227	227	Четверг             	11:00:00
228	228	Четверг             	12:00:00
229	229	Четверг             	13:00:00
230	230	Четверг             	14:00:00
231	231	Четверг             	15:00:00
232	232	Четверг             	16:00:00
233	233	Пятница             	17:00:00
234	234	Пятница             	09:00:00
235	235	Пятница             	10:00:00
236	236	Пятница             	11:00:00
237	237	Пятница             	12:00:00
238	238	Пятница             	13:00:00
239	239	Пятница             	14:00:00
240	240	Пятница             	15:00:00
241	241	Пятница             	16:00:00
242	242	Пятница             	17:00:00
243	243	Пятница             	18:00:00
244	244	Пятница             	09:00:00
245	245	Пятница             	10:00:00
246	246	Пятница             	11:00:00
247	247	Пятница             	12:00:00
248	248	Пятница             	13:00:00
249	249	Пятница             	14:00:00
250	250	Пятница             	15:00:00
251	251	Пятница             	16:00:00
252	252	Пятница             	17:00:00
253	253	Пятница             	18:00:00
254	254	Пятница             	19:00:00
255	255	Суббота             	09:00:00
256	256	Суббота             	10:00:00
257	257	Суббота             	11:00:00
258	258	Суббота             	12:00:00
259	259	Суббота             	13:00:00
260	260	Суббота             	14:00:00
261	261	Суббота             	15:00:00
262	262	Суббота             	16:00:00
263	263	Суббота             	17:00:00
264	264	Суббота             	09:00:00
265	265	Суббота             	10:00:00
266	266	Суббота             	11:00:00
267	267	Суббота             	12:00:00
268	268	Суббота             	13:00:00
269	269	Суббота             	14:00:00
270	270	Суббота             	15:00:00
271	271	Суббота             	16:00:00
272	272	Суббота             	17:00:00
273	273	Суббота             	18:00:00
274	274	Воскресенье         	09:00:00
275	275	Воскресенье         	10:00:00
276	276	Воскресенье         	11:00:00
277	277	Воскресенье         	12:00:00
278	278	Воскресенье         	13:00:00
279	279	Воскресенье         	14:00:00
280	280	Воскресенье         	15:00:00
281	281	Воскресенье         	16:00:00
282	282	Воскресенье         	17:00:00
283	283	Воскресенье         	18:00:00
284	284	Воскресенье         	19:00:00
285	285	Воскресенье         	20:00:00
286	286	Воскресенье         	21:00:00
287	287	Воскресенье         	22:00:00
288	288	Воскресенье         	09:00:00
289	289	Воскресенье         	10:00:00
290	290	Воскресенье         	11:00:00
291	291	Воскресенье         	12:00:00
292	292	Воскресенье         	13:00:00
\.


                                                                                                                   4915.dat                                                                                            0000600 0004000 0002000 00000000725 14630037536 0014267 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1	1	СпортЛайф                 	1
2	2	ФитнесПро                 	6
3	3	АктивныйВыбор             	11
4	4	ЭнергияСпорта             	16
5	5	СпортМастер               	21
6	6	ЗдоровыйТренаж            	26
7	7	ВеликийФитнес             	31
8	8	АктивнаяФорма             	34
9	9	ФитнесГалактика           	41
10	10	ТренажерныйМир            	44
\.


                                           4923.dat                                                                                            0000600 0004000 0002000 00000000466 14630037536 0014270 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        2	2850
3	2100
4	2100
5	2850
7	2100
8	2100
9	2100
10	2850
12	2100
13	2850
14	2100
15	2600
17	2100
18	2100
19	2600
20	2100
22	2100
23	2600
24	2100
25	2100
27	2600
28	2100
29	2100
30	2850
32	2100
33	2850
35	3000
36	2100
37	2100
38	2600
39	2100
40	2600
42	2600
43	2100
45	2600
46	2600
47	2600
48	2850
49	2600
\.


                                                                                                                                                                                                          4918.dat                                                                                            0000600 0004000 0002000 00000000443 14630037536 0014267 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        Аэробика            	1000
Бокс                	1500
Фитнес              	1300
Кроссфит            	800
Танцы               	800
Борьба              	1400
Йога                	1300
Батуты              	800
Растяжка            	1000
\.


                                                                                                                                                                                                                             restore.sql                                                                                         0000600 0004000 0002000 00000066320 14630037536 0015402 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        --
-- NOTE:
--
-- File paths need to be edited. Search for $$PATH$$ and
-- replace it with the path to the directory containing
-- the extracted data files.
--
--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE "Gym final";
--
-- Name: Gym final; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE "Gym final" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';


ALTER DATABASE "Gym final" OWNER TO postgres;

\connect -reuse-previous=on "dbname='Gym final'"

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: calculate_membership_price(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_membership_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    freeze_price INT;
    months_price INT;
BEGIN
    SELECT price_per_month INTO months_price FROM Rates WHERE id_rate = NEW.id_rate;
    SELECT price_per_30_days_of_freezing INTO freeze_price FROM Rates WHERE id_rate = NEW.id_rate;
    
    freeze_price := freeze_price * NEW.freezing/30;
    months_price := months_price * NEW.duaration;
    
    NEW.price := months_price + freeze_price;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculate_membership_price() OWNER TO postgres;

--
-- Name: calculate_training_price(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_training_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    certificate_count INT;
BEGIN
    -- Подсчет количества сертификатов у тренера
    SELECT COUNT(*) INTO certificate_count
    FROM certificates
    WHERE id_employee = NEW.id_employee;

    -- Установка цены за тренировку по формуле 3*(1.2 - (1 / (certificate_count + 1)))
    NEW.price_per_training := 3 * (1.2 - (1.0 / (certificate_count + 1))) * 1000;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculate_training_price() OWNER TO postgres;

--
-- Name: check_client_employee_same_gym_and_active_membership(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_client_employee_same_gym_and_active_membership() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    client_gym_id INT;
    employee_gym_id INT;
    membership_active BOOLEAN;
BEGIN
    -- Получаем id_Gym для клиента и проверяем, что абонемент активен
    SELECT id_Gym, active_inactive = 'да' into client_gym_id, membership_active
    FROM GymMembership
    WHERE id_Client = NEW.id_Client
    LIMIT 1; -- Предполагаем, что клиент зарегистрирован хотя бы в одном зале

    -- Получаем id_Gym для сотрудника
    SELECT id_Gym INTO employee_gym_id
    FROM employees
    WHERE id_employee = NEW.id_employee;

    -- Проверяем, что клиент и сотрудник зарегистрированы в одном и том же зале
    -- и что абонемент клиента активен
    IF client_gym_id IS NULL OR employee_gym_id IS NULL OR client_gym_id <> employee_gym_id OR NOT membership_active THEN
        RAISE EXCEPTION 'Клиент (id_Client = %) и сотрудник (id_employee = %) не зарегистрированы в одном и том же зале или абонемент клиента не активен', NEW.id_Client, NEW.id_employee;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_client_employee_same_gym_and_active_membership() OWNER TO postgres;

--
-- Name: check_employee_position(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_employee_position() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    employee_position CHAR(20);
BEGIN
    -- Извлекаем должность сотрудника из таблицы employees
    SELECT position INTO employee_position
    FROM employees
    WHERE id_employee = NEW.id_employee;
    
    -- Проверяем, что должность сотрудника "продавец"
    IF employee_position <> 'Продавец' THEN
        RAISE EXCEPTION 'Сотрудник (id_employee = %) не является продавцом', NEW.id_employee;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_employee_position() OWNER TO postgres;

--
-- Name: check_schedule_conflict(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_schedule_conflict() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM schedule
        WHERE id_group = NEW.id_group
        AND day_of_week = NEW.day_of_week
        AND start_time = NEW.start_time
    ) THEN
        RAISE EXCEPTION 'Ошибка при попытке вставить новую запись. Наложение занятий.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_schedule_conflict() OWNER TO postgres;

--
-- Name: check_scheduletr_conflicts(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_scheduletr_conflicts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    conflicting_trainer INT;
    conflicting_client INT;
BEGIN
    -- Проверка на конфликт тренера
    SELECT COUNT(*)
    INTO conflicting_trainer
    FROM scheduletr st
    JOIN individualtr it ON st.id_individualtr = it.id_individualtr
    WHERE it.id_employee = (SELECT it2.id_employee FROM individualtr it2 WHERE it2.id_individualtr = NEW.id_individualtr)
    AND st.start_time = NEW.start_time
    AND st.day_of_week = NEW.day_of_week
    AND st.id <> NEW.id;

    IF conflicting_trainer > 0 THEN
        RAISE EXCEPTION 'Тренер уже занят в это время на другой тренировке';
    END IF;

    -- Проверка на конфликт клиента
    SELECT COUNT(*)
    INTO conflicting_client
    FROM scheduletr st
    JOIN individualtr it ON st.id_individualtr = it.id_individualtr
    WHERE it.id_client = (SELECT it2.id_client FROM individualtr it2 WHERE it2.id_individualtr = NEW.id_individualtr)
    AND st.start_time = NEW.start_time
    AND st.day_of_week = NEW.day_of_week
    AND st.id <> NEW.id;

    IF conflicting_client > 0 THEN
        RAISE EXCEPTION 'Клиент уже занят в это время на другой тренировке';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_scheduletr_conflicts() OWNER TO postgres;

--
-- Name: set_rate_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_rate_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    selected_rate_id int;
begin
    -- Поиск тарифа, действующего на дату покупки
    select id_rate
    into selected_rate_id
    from Rates
    where new.date_of_purchase between start_date and end_date
    limit 1;

    -- Если тариф найден, устанавливаем id_rate
    if found then
        new.id_rate := selected_rate_id;
    else
        raise exception 'No valid rate found for the purchase date %', new.date_of_purchase;
    end if;

    return new;
end;
$$;


ALTER FUNCTION public.set_rate_id() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: certificates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificates (
    id_certificate integer NOT NULL,
    id_employee integer,
    certificate_name character(100)
);


ALTER TABLE public.certificates OWNER TO postgres;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id_client integer NOT NULL,
    surname character(20),
    first_name character(20),
    patronymic character(20),
    gender character(10),
    date_of_birth date,
    phone_number character(20),
    CONSTRAINT clients_gender_check CHECK ((gender = ANY (ARRAY['м'::bpchar, 'ж'::bpchar])))
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employees (
    id_employee integer NOT NULL,
    id_gym integer,
    surname character(20),
    first_name character(20),
    patronymic character(20),
    date_of_birth date,
    salaty integer,
    "position" character(20)
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- Name: groupclient; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groupclient (
    id_group integer NOT NULL,
    id_client integer NOT NULL
);


ALTER TABLE public.groupclient OWNER TO postgres;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groups (
    id_group integer NOT NULL,
    id_gym integer,
    id_employee integer,
    training_name character(20)
);


ALTER TABLE public.groups OWNER TO postgres;

--
-- Name: gym; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gym (
    id_gym integer NOT NULL,
    opening_time time without time zone,
    closing_time time without time zone,
    address character(150),
    phone_number character(20)
);


ALTER TABLE public.gym OWNER TO postgres;

--
-- Name: gymmembership; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gymmembership (
    id_membership integer NOT NULL,
    id_gym integer,
    id_client integer,
    id_rate integer,
    duaration integer,
    freezing integer,
    price integer,
    date_of_purchase date,
    start_date date,
    active_inactive character(3),
    CONSTRAINT chk_freezing CHECK ((freezing = ANY (ARRAY[0, 30, 60, 90]))),
    CONSTRAINT gymmembership_active_inactive_check CHECK ((active_inactive = ANY (ARRAY['да'::bpchar, 'нет'::bpchar])))
);


ALTER TABLE public.gymmembership OWNER TO postgres;

--
-- Name: gymmembership_id_membership_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.gymmembership_id_membership_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gymmembership_id_membership_seq OWNER TO postgres;

--
-- Name: gymmembership_id_membership_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.gymmembership_id_membership_seq OWNED BY public.gymmembership.id_membership;


--
-- Name: individualtr; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.individualtr (
    id_employee integer,
    id_client integer,
    id_individualtr integer NOT NULL
);


ALTER TABLE public.individualtr OWNER TO postgres;

--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    id_product integer NOT NULL,
    product_name character(20),
    price integer
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: productstore; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productstore (
    id_product integer NOT NULL,
    id_store integer NOT NULL,
    quantity integer
);


ALTER TABLE public.productstore OWNER TO postgres;

--
-- Name: rates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rates (
    id_rate integer NOT NULL,
    price_per_month integer,
    price_per_30_days_of_freezing integer,
    start_date date,
    end_date date
);


ALTER TABLE public.rates OWNER TO postgres;

--
-- Name: schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule (
    id_training integer NOT NULL,
    day_of_week character(20),
    id_group integer,
    start_time time without time zone,
    CONSTRAINT schedule_day_of_week_check CHECK ((day_of_week = ANY (ARRAY['Понедельник'::bpchar, 'Вторник'::bpchar, 'Среда'::bpchar, 'Четверг'::bpchar, 'Пятница'::bpchar, 'Суббота'::bpchar, 'Воскресенье'::bpchar])))
);


ALTER TABLE public.schedule OWNER TO postgres;

--
-- Name: scheduletr; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scheduletr (
    id integer NOT NULL,
    id_individualtr integer,
    day_of_week character(20),
    start_time time without time zone,
    CONSTRAINT scheduletr_day_of_week_check CHECK ((day_of_week = ANY (ARRAY['Понедельник'::bpchar, 'Вторник'::bpchar, 'Среда'::bpchar, 'Четверг'::bpchar, 'Пятница'::bpchar, 'Суббота'::bpchar, 'Воскресенье'::bpchar])))
);


ALTER TABLE public.scheduletr OWNER TO postgres;

--
-- Name: store; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.store (
    id_store integer NOT NULL,
    id_gym integer,
    store_name character(26),
    id_employee integer
);


ALTER TABLE public.store OWNER TO postgres;

--
-- Name: trainerrates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trainerrates (
    id_employee integer NOT NULL,
    price_per_training integer
);


ALTER TABLE public.trainerrates OWNER TO postgres;

--
-- Name: trainings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trainings (
    training_name character(20) NOT NULL,
    price_per_tr integer
);


ALTER TABLE public.trainings OWNER TO postgres;

--
-- Name: gymmembership id_membership; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gymmembership ALTER COLUMN id_membership SET DEFAULT nextval('public.gymmembership_id_membership_seq'::regclass);


--
-- Data for Name: certificates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificates (id_certificate, id_employee, certificate_name) FROM stdin;
\.
COPY public.certificates (id_certificate, id_employee, certificate_name) FROM '$$PATH$$/4914.dat';

--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id_client, surname, first_name, patronymic, gender, date_of_birth, phone_number) FROM stdin;
\.
COPY public.clients (id_client, surname, first_name, patronymic, gender, date_of_birth, phone_number) FROM '$$PATH$$/4909.dat';

--
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employees (id_employee, id_gym, surname, first_name, patronymic, date_of_birth, salaty, "position") FROM stdin;
\.
COPY public.employees (id_employee, id_gym, surname, first_name, patronymic, date_of_birth, salaty, "position") FROM '$$PATH$$/4913.dat';

--
-- Data for Name: groupclient; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groupclient (id_group, id_client) FROM stdin;
\.
COPY public.groupclient (id_group, id_client) FROM '$$PATH$$/4920.dat';

--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groups (id_group, id_gym, id_employee, training_name) FROM stdin;
\.
COPY public.groups (id_group, id_gym, id_employee, training_name) FROM '$$PATH$$/4919.dat';

--
-- Data for Name: gym; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gym (id_gym, opening_time, closing_time, address, phone_number) FROM stdin;
\.
COPY public.gym (id_gym, opening_time, closing_time, address, phone_number) FROM '$$PATH$$/4908.dat';

--
-- Data for Name: gymmembership; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gymmembership (id_membership, id_gym, id_client, id_rate, duaration, freezing, price, date_of_purchase, start_date, active_inactive) FROM stdin;
\.
COPY public.gymmembership (id_membership, id_gym, id_client, id_rate, duaration, freezing, price, date_of_purchase, start_date, active_inactive) FROM '$$PATH$$/4912.dat';

--
-- Data for Name: individualtr; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.individualtr (id_employee, id_client, id_individualtr) FROM stdin;
\.
COPY public.individualtr (id_employee, id_client, id_individualtr) FROM '$$PATH$$/4921.dat';

--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (id_product, product_name, price) FROM stdin;
\.
COPY public.products (id_product, product_name, price) FROM '$$PATH$$/4916.dat';

--
-- Data for Name: productstore; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.productstore (id_product, id_store, quantity) FROM stdin;
\.
COPY public.productstore (id_product, id_store, quantity) FROM '$$PATH$$/4917.dat';

--
-- Data for Name: rates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rates (id_rate, price_per_month, price_per_30_days_of_freezing, start_date, end_date) FROM stdin;
\.
COPY public.rates (id_rate, price_per_month, price_per_30_days_of_freezing, start_date, end_date) FROM '$$PATH$$/4910.dat';

--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule (id_training, day_of_week, id_group, start_time) FROM stdin;
\.
COPY public.schedule (id_training, day_of_week, id_group, start_time) FROM '$$PATH$$/4922.dat';

--
-- Data for Name: scheduletr; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scheduletr (id, id_individualtr, day_of_week, start_time) FROM stdin;
\.
COPY public.scheduletr (id, id_individualtr, day_of_week, start_time) FROM '$$PATH$$/4924.dat';

--
-- Data for Name: store; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.store (id_store, id_gym, store_name, id_employee) FROM stdin;
\.
COPY public.store (id_store, id_gym, store_name, id_employee) FROM '$$PATH$$/4915.dat';

--
-- Data for Name: trainerrates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trainerrates (id_employee, price_per_training) FROM stdin;
\.
COPY public.trainerrates (id_employee, price_per_training) FROM '$$PATH$$/4923.dat';

--
-- Data for Name: trainings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trainings (training_name, price_per_tr) FROM stdin;
\.
COPY public.trainings (training_name, price_per_tr) FROM '$$PATH$$/4918.dat';

--
-- Name: gymmembership_id_membership_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.gymmembership_id_membership_seq', 1, false);


--
-- Name: certificates certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id_certificate);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id_client);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id_employee);


--
-- Name: groupclient groupclient_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupclient
    ADD CONSTRAINT groupclient_pkey PRIMARY KEY (id_group, id_client);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id_group);


--
-- Name: gym gym_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gym
    ADD CONSTRAINT gym_pkey PRIMARY KEY (id_gym);


--
-- Name: gymmembership gymmembership_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT gymmembership_pkey PRIMARY KEY (id_membership);


--
-- Name: individualtr individualtr_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.individualtr
    ADD CONSTRAINT individualtr_pkey PRIMARY KEY (id_individualtr);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id_product);


--
-- Name: productstore productstore_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productstore
    ADD CONSTRAINT productstore_pkey PRIMARY KEY (id_product, id_store);


--
-- Name: rates rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rates
    ADD CONSTRAINT rates_pkey PRIMARY KEY (id_rate);


--
-- Name: schedule schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (id_training);


--
-- Name: scheduletr scheduletr_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduletr
    ADD CONSTRAINT scheduletr_pkey PRIMARY KEY (id);


--
-- Name: store store_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (id_store);


--
-- Name: trainerrates trainerrates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trainerrates
    ADD CONSTRAINT trainerrates_pkey PRIMARY KEY (id_employee);


--
-- Name: trainings trainings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trainings
    ADD CONSTRAINT trainings_pkey PRIMARY KEY (training_name);


--
-- Name: gymmembership schedule_conflict; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER schedule_conflict AFTER INSERT ON public.gymmembership FOR EACH ROW EXECUTE FUNCTION public.check_schedule_conflict();


--
-- Name: trainerrates set_training_price; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_training_price BEFORE INSERT OR UPDATE ON public.trainerrates FOR EACH ROW EXECUTE FUNCTION public.calculate_training_price();


--
-- Name: individualtr tr2; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr2 BEFORE INSERT ON public.individualtr FOR EACH ROW EXECUTE FUNCTION public.check_client_employee_same_gym_and_active_membership();


--
-- Name: store trg_check_employee_position; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_employee_position BEFORE INSERT ON public.store FOR EACH ROW EXECUTE FUNCTION public.check_employee_position();


--
-- Name: scheduletr trg_check_scheduletr_conflicts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_scheduletr_conflicts BEFORE INSERT OR UPDATE ON public.scheduletr FOR EACH ROW EXECUTE FUNCTION public.check_scheduletr_conflicts();


--
-- Name: gymmembership trg_set_rate_id; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_set_rate_id BEFORE INSERT ON public.gymmembership FOR EACH ROW EXECUTE FUNCTION public.set_rate_id();


--
-- Name: gymmembership update_membership_price; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_membership_price BEFORE INSERT OR UPDATE OF id_rate, duaration, freezing ON public.gymmembership FOR EACH ROW EXECUTE FUNCTION public.calculate_membership_price();


--
-- Name: gymmembership f1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT f1 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);


--
-- Name: groups f10; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT f10 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);


--
-- Name: groups f11; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT f11 FOREIGN KEY (training_name) REFERENCES public.trainings(training_name);


--
-- Name: groupclient f12; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupclient
    ADD CONSTRAINT f12 FOREIGN KEY (id_group) REFERENCES public.groups(id_group);


--
-- Name: groupclient f13; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupclient
    ADD CONSTRAINT f13 FOREIGN KEY (id_client) REFERENCES public.clients(id_client);


--
-- Name: individualtr f14; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.individualtr
    ADD CONSTRAINT f14 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);


--
-- Name: individualtr f15; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.individualtr
    ADD CONSTRAINT f15 FOREIGN KEY (id_client) REFERENCES public.clients(id_client);


--
-- Name: schedule f16; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT f16 FOREIGN KEY (id_group) REFERENCES public.groups(id_group);


--
-- Name: trainerrates f17; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trainerrates
    ADD CONSTRAINT f17 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);


--
-- Name: scheduletr f18; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scheduletr
    ADD CONSTRAINT f18 FOREIGN KEY (id_individualtr) REFERENCES public.individualtr(id_individualtr);


--
-- Name: store f19; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store
    ADD CONSTRAINT f19 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);


--
-- Name: gymmembership f2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT f2 FOREIGN KEY (id_client) REFERENCES public.clients(id_client);


--
-- Name: gymmembership f3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gymmembership
    ADD CONSTRAINT f3 FOREIGN KEY (id_rate) REFERENCES public.rates(id_rate);


--
-- Name: employees f4; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT f4 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);


--
-- Name: certificates f5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT f5 FOREIGN KEY (id_employee) REFERENCES public.employees(id_employee);


--
-- Name: store f6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store
    ADD CONSTRAINT f6 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);


--
-- Name: productstore f7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productstore
    ADD CONSTRAINT f7 FOREIGN KEY (id_product) REFERENCES public.products(id_product);


--
-- Name: productstore f8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productstore
    ADD CONSTRAINT f8 FOREIGN KEY (id_store) REFERENCES public.store(id_store);


--
-- Name: groups f9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT f9 FOREIGN KEY (id_gym) REFERENCES public.gym(id_gym);


--
-- PostgreSQL database dump complete
--

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                