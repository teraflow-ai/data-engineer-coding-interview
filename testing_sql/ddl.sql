-- Quick and dirty ddl script to set up pg schema:

CREATE TABLE IF NOT EXISTS public.tbl_bank
(
    id_bank serial NOT NULL,
    name character varying(120) COLLATE pg_catalog."default",
    capitalization integer,
    CONSTRAINT id_bank PRIMARY KEY (id_bank)
)

TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS public.tbl_branch
(
    id_branch serial NOT NULL,
    bank_id_bank integer,
    address character varying(255) COLLATE pg_catalog."default",
    CONSTRAINT id_branch PRIMARY KEY (id_branch)
)

TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS public.tbl_client
(
    id_client serial NOT NULL,
    name character varying(50) COLLATE pg_catalog."default",
    surname character varying(50) COLLATE pg_catalog."default",
    branch_id_branch integer,
    CONSTRAINT id_client PRIMARY KEY (id_client)
)

TABLESPACE pg_default;

CREATE TABLE IF NOT EXISTS public.tbl_account
(
    id_account serial NOT NULL,
    balance integer,
    client_client_id integer,
    open_date date,
    CONSTRAINT id_account PRIMARY KEY (id_account)
)

TABLESPACE pg_default;

CREATE TABLE IF NOT EXISTS public.tbl_loans
(
    id_loan serial NOT NULL,
    amount integer,
    account_id_account integer,
    loan_date date,
    CONSTRAINT id_cid_loanlient PRIMARY KEY (id_loan)
)

TABLESPACE pg_default;