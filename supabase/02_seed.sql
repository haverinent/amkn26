-- =====================================================================
-- 2) Alkutiedot: ylläpitäjä ja kurssit
-- VAIHDA alla oleva sähköpostiosoite omaksesi ennen ajamista!
-- =====================================================================

insert into public.allowed_emails (email, is_admin) values (lower('OMA@SAHKOPOSTI.FI'), true)
  on conflict (email) do update set is_admin = true;

insert into public.courses (code, name) values
  ('HARJO1', 'Ammattiin orientoituminen 1'),
  ('HARJO2', 'Ammattiin orientoituminen 2'),
  ('HARJO3', 'Ammattiin orientoituminen 3'),
  ('ENGOF1', 'English for Fire Officers'),
  ('ENGRE1', 'English for Rescue Services'),
  ('ENHAL', 'Ensihoidon hallinto'),
  ('ENSIH', 'Ensihoito'),
  ('FY', 'Fysiikka'),
  ('HENJO', 'Henkilöstöjohtaminen'),
  ('JOHDA', 'Johdatus amk-opintoihin'),
  ('JOHSU', 'Johtamissuunnittelun perusteet'),
  ('KEMIA', 'Kemia'),
  ('KVALI', 'Kvalitatiiviset tutkimusmenetelmät'),
  ('KVANT', 'Kvantitatiiviset tutkimusmenetelmät'),
  ('LIIKU', 'Liikuntakasvatus'),
  ('MA1', 'Matematiikka 1'),
  ('MA2', 'Matematiikka 2'),
  ('MUUTO', 'Muutosjohtaminen'),
  ('OMAJO1', 'Oman johtajuuden kehittäminen'),
  ('ONNEH2', 'Onnettomuuksien ehkäisyn perusteet'),
  ('OPSUU', 'Opinnäytetyön suunnittelu'),
  ('PALFY', 'Palofysiikan jatkokurssi'),
  ('PFYPE', 'Palofysiikan perusteet'),
  ('PALTU1', 'Palontutkinta'),
  ('PALLA', 'Palotekniset laitteistot'),
  ('PATUPE', 'Paloturvallisuustekniikan perusteet'),
  ('PEPEO', 'Pedagogiikka ja oppiminen pelastusalalla'),
  ('PELJJ', 'Pelastusjoukkueen johtaminen'),
  ('PELKP', 'Pelastuskomppanian johtamisen perusteet'),
  ('PTJV', 'Pelastustoimen tietotekniset järjestelmät ja välineet'),
  ('PEMAL', 'Pelastustoimi ja julkinen hallinto'),
  ('PELJP', 'Pelastustoiminnan johtamisen perusteet'),
  ('PETIK', 'Päällystön etiketti ja käyttäytyminen'),
  ('RAKTE1', 'Rakennustekniikka'),
  ('RAKPA', 'Rakenteellinen paloturvallisuus'),
  ('RISKI', 'Riskienhallinta'),
  ('SAPE1', 'Sammutus- ja pelastustekniikka I'),
  ('SAPE2A', 'Sammutus- ja pelastustekniikka II'),
  ('STUPE', 'Sisäisen turvallisuuden perusteet'),
  ('RUSTÖ', 'Stödkurs i svenska'),
  ('RUBRA', 'Svenska för brandbefä, muntlig'),
  ('RURÄD', 'Svenska för räddningsbranschen, skriftlig'),
  ('HARJO4', 'Syventävä harjoittelu 1'),
  ('HARJO5', 'Syventävä harjoittelu 2'),
  ('PELJV1', 'Tiedottaminen'),
  ('HALLI', 'Toimialan hallinto ja talous'),
  ('VALVI', 'Turvallisuusviestintä'),
  ('TOIMI', 'Tutkimustoiminnan perusteet'),
  ('SUOMI3', 'Tutkimusviestintä'),
  ('VAARA', 'Vaaralliset aineet'),
  ('VALPK1n', 'Valvonnan perusteet, osa 1.'),
  ('VALPK2n', 'Valvonnan perusteet, osa 2.'),
  ('VIEHÄ', 'Viestiliikenne ja hätäkeskustoiminta'),
  ('SUOMI2', 'Viestintä päätöksenteossa'),
  ('SUOMI1', 'Viestintätaitojen perusteet'),
  ('PELJV2', 'Viranomaisyhteistoiminnan johtaminen'),
  ('YMPTU', 'Ympäristöturvallisuus')
on conflict (code) do nothing;

-- Alkuperäiset tehtävät on tuotu tietokantaan erikseen, eikä niitä pidetä
-- julkisessa repossa. Uudet tehtävät lisätään sovelluksen kautta.
