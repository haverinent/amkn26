# Opintotehtävät N26

Kurssin yhteinen oppimistehtävien ja tenttien seuranta. Tehtävät ovat yhteisiä, ja jokaisella on oma kori, jossa hän seuraa omaa statustaan.

- **Sivu:** GitHub Pages (`index.html`, `config.js`)
- **Tietokanta ja kirjautuminen:** Supabase (EU). Kirjautuminen sähköpostiin lähetettävällä linkillä, ja pääsy vain sallittujen listalla oleville.

## Käyttöönotto
1. Supabase → **SQL Editor**: aja järjestyksessä
   1. `supabase/01_schema.sql` (taulut ja käyttöoikeudet)
   2. `supabase/02_seed.sql` (vaihda ensin oma sähköpostisi riville `OMA@SAHKOPOSTI.FI` – vain SQL Editoriin, ei repoon)
2. Supabase → **Authentication → URL Configuration**
   - Site URL: `https://haverinent.github.io/amkn26/`
   - Redirect URLs: `https://haverinent.github.io/amkn26/**`
3. GitHub → **Settings → Pages** → Deploy from branch → `main` / `(root)`
5. Lisää kurssilaisten osoitteet sovelluksen **Ylläpito**-välilehdellä.

## Tietosuoja
Tallennetaan vain sähköposti (kirjautuminen, näkyy vain ylläpitäjälle), etunimi tai nimimerkki ja omat statukset. Repossa ei ole henkilötietoja. `config.js`:n avain on julkinen *publishable*-avain, ja varsinainen suojaus on tietokannan RLS-säännöissä.
