-- Insert statements for Bank table
INSERT INTO public.bank ("name", "capitalization") VALUES
  ('Bank A', 100000),
  ('Bank B', 200000),
  ('Bank C', 150000),
  ('Bank D', 180000),
  ('Bank E', 120000);

-- Insert statements for Branch table
INSERT INTO public.branch ("address", "idbank_bank") VALUES
  ('Branch A1', 1),
  ('Branch A2', 1),
  ('Branch B1', 2),
  ('Branch B2', 2),
  ('Branch C1', 3),
  ('Branch C2', 3),
  ('Branch D1', 4),
  ('Branch D2', 4),
  ('Branch E1', 5),
  ('Branch E2', 5);

-- Insert statements for Client table
INSERT INTO public.client ("name", "surname", "idbranch_branch") VALUES
  ('John', 'Doe', 1),
  ('Jane', 'Smith', 1),
  ('Michael', 'Johnson', 2),
  ('Sarah', 'Williams', 2),
  ('David', 'Brown', 3),
  ('Emily', 'Davis', 3),
  ('Daniel', 'Miller', 4),
  ('Olivia', 'Taylor', 4),
  ('Alexander', 'Anderson', 5),
  ('Sophia', 'Moore', 5);

-- Insert statements for Account table
INSERT INTO public.account ("balance", "open_data", "idclient_client") VALUES
  (10000, '2023-01-01', 1),
  (20000, '2023-01-01', 2),
  (15000, '2023-02-01', 3),
  (25000, '2023-02-01', 4),
  (12000, '2023-03-01', 5),
  (18000, '2023-03-01', 6),
  (22000, '2023-04-01', 7),
  (16000, '2023-04-01', 8),
  (19000, '2023-05-01', 9),
  (21000, '2023-05-01', 10);

-- Insert statements for Loans table
INSERT INTO public.loans ("amount", "loan_date", "idaccount_account") VALUES
  (5000, '2023-01-15', 1),
  (8000, '2023-01-20', 2),
  (6000, '2023-02-10', 3),
  (7000, '2023-02-25', 4),
  (4000, '2023-03-05', 5),
  (9000, '2023-03-15', 6),
  (3500, '2023-04-07', 7),
  (5500, '2023-04-25', 8),
  (7500, '2023-05-10', 9),
  (6500, '2023-05-22', 10);

