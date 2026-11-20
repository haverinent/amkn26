# AmkN26 OPO

Kurssin yhteinen oppimistehtävien ja tenttien seuranta. Tehtävät ovat yhteisiä, ja jokaisella on oma kori, jossa hän seuraa omaa statustaan.

- **Sivu:** GitHub Pages (`index.html`, `config.js`) – https://haverinent.github.io/amkn26/
- **Tietokanta:** Supabase (EU)
- **Kirjautuminen:** käyttäjätunnus ja salasana, jotka ylläpitäjä luo. Sähköposteja ei tallenneta.

## Tietokannan muutokset (Supabase → SQL Editor, järjestyksessä)
`supabase/01` … `supabase/10`. Ylläpitäjän ensimmäinen tunnus luodaan erikseen (ei repossa). Muut jäsenet lisätään sovelluksen **Ylläpito**-välilehdellä.

## Tietosuoja
Tallennetaan vain etunimi tai nimimerkki, käyttäjätunnus, salasanan tiiviste (bcrypt), oma kori ja viimeisin käyttöpäivä. Taulut ovat lukossa, ja kaikki toiminnot kulkevat kirjautumisen tarkistavien funktioiden kautta. `config.js`:n avain on julkinen *publishable*-avain.
