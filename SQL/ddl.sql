-- Database generated with pgModeler (PostgreSQL Database Modeler).
-- pgModeler version: 1.0.3
-- PostgreSQL version: 15.0
-- Project Site: pgmodeler.io
-- Model Author: ---

-- Database creation must be performed outside a multi lined SQL file.
-- These commands were put in this file only as a convenience.
--
-- object: mydatabase | type: DATABASE --
-- DROP DATABASE IF EXISTS mydatabase;
-- CREATE DATABASE mydatabase;
-- ddl-end --


-- object: public.bank | type: TABLE --
-- DROP TABLE IF EXISTS public.bank;
CREATE TABLE public.bank (
        idbank integer NOT NULL GENERATED ALWAYS AS IDENTITY ,
        name varchar(100),
        capitalization integer,
        CONSTRAINT bank_pk PRIMARY KEY (idbank)
)
TABLESPACE pg_default;
-- ddl-end --
ALTER TABLE public.bank OWNER TO postgres;
-- ddl-end --

-- object: public.branch | type: TABLE --
-- DROP TABLE IF EXISTS public.branch;
CREATE TABLE public.branch (
        idbranch integer NOT NULL GENERATED ALWAYS AS IDENTITY ,
        address varchar(255),
        idbank_bank integer,
        CONSTRAINT branch_pk PRIMARY KEY (idbranch)
)
TABLESPACE pg_default;
-- ddl-end --
ALTER TABLE public.branch OWNER TO postgres;
-- ddl-end --

-- object: bank_fk | type: CONSTRAINT --
-- ALTER TABLE public.branch DROP CONSTRAINT IF EXISTS bank_fk CASCADE;
ALTER TABLE public.branch ADD CONSTRAINT bank_fk FOREIGN KEY (idbank_bank)
REFERENCES public.bank (idbank) MATCH FULL
ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --

-- object: public.client | type: TABLE --
-- DROP TABLE IF EXISTS public.client;
CREATE TABLE public.client (
        idclient integer NOT NULL GENERATED ALWAYS AS IDENTITY ,
        name varchar(50),
        surname varchar(50),
        idbranch_branch integer,
        CONSTRAINT client_pk PRIMARY KEY (idclient)
)
TABLESPACE pg_default;
-- ddl-end --
ALTER TABLE public.client OWNER TO postgres;
-- ddl-end --

-- object: branch_fk | type: CONSTRAINT --
-- ALTER TABLE public.client DROP CONSTRAINT IF EXISTS branch_fk CASCADE;
ALTER TABLE public.client ADD CONSTRAINT branch_fk FOREIGN KEY (idbranch_branch)
REFERENCES public.branch (idbranch) MATCH FULL
ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --

-- object: public.account | type: TABLE --
-- DROP TABLE IF EXISTS public.account;
CREATE TABLE public.account (
        idaccount integer NOT NULL GENERATED ALWAYS AS IDENTITY ,
        balance integer,
        open_data date,
        idclient_client integer,
        CONSTRAINT account_pk PRIMARY KEY (idaccount)
)
TABLESPACE pg_default;
-- ddl-end --
ALTER TABLE public.account OWNER TO postgres;
-- ddl-end --

-- object: public.loans | type: TABLE --
-- DROP TABLE IF EXISTS public.loans;
CREATE TABLE public.loans (
        idloan integer NOT NULL GENERATED ALWAYS AS IDENTITY ,
        amount integer,
        loan_data date,
        idaccount_account integer,
        CONSTRAINT loans_pk PRIMARY KEY (idloan)
)
TABLESPACE pg_default;
-- ddl-end --
ALTER TABLE public.loans OWNER TO postgres;
-- ddl-end --

-- object: client_fk | type: CONSTRAINT --
-- ALTER TABLE public.account DROP CONSTRAINT IF EXISTS client_fk CASCADE;
ALTER TABLE public.account ADD CONSTRAINT client_fk FOREIGN KEY (idclient_client)
REFERENCES public.client (idclient) MATCH FULL
ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --

-- object: account_uq | type: CONSTRAINT --
-- ALTER TABLE public.account DROP CONSTRAINT IF EXISTS account_uq CASCADE;
ALTER TABLE public.account ADD CONSTRAINT account_uq UNIQUE (idclient_client);
-- ddl-end --

-- object: account_fk | type: CONSTRAINT --
-- ALTER TABLE public.loans DROP CONSTRAINT IF EXISTS account_fk CASCADE;
ALTER TABLE public.loans ADD CONSTRAINT account_fk FOREIGN KEY (idaccount_account)
REFERENCES public.account (idaccount) MATCH FULL
ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --

