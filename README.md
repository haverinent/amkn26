# Opintotehtävät N26

Kurssin yhteinen oppimistehtävien ja tenttien seuranta. Tehtävät ovat yhteisiä, ja jokaisella on oma kori, jossa hän seuraa omaa statustaan.

- **Sivu:** GitHub Pages (`index.html`, `config.js`) – https://haverinent.github.io/amkn26/
- **Tietokanta:** Supabase (EU)
- **Pääsy:** henkilökohtaisella linkillä (`…/amkn26/#k=…`). Sähköposteja ei tallenneta.

## Käyttöönotto (Supabase → SQL Editor)
1. `supabase/01_schema.sql` – perustaulut
2. `supabase/02_seed.sql` – kurssilista
3. `supabase/04_henkilokohtaiset_linkit.sql` – linkkipohjainen pääsy ja käyttöoikeudet
4. Ylläpitäjän ensimmäinen linkki luodaan erillisellä SQL:llä (ei repossa).
5. Muiden linkit luodaan sovelluksen **Ylläpito**-välilehdellä.

## Tietosuoja
Tallennetaan vain etunimi tai nimimerkki, omat statukset ja viimeisin käyttöpäivä. Linkeistä tallennetaan vain tiiviste (SHA-256), joten tietokannasta ei voi lukea niitä. Taulut ovat lukossa, ja kaikki toiminnot kulkevat linkin tarkistavien funktioiden kautta. `config.js`:n avain on julkinen *publishable*-avain.
