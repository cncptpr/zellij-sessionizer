```sql
SELECT v.Titel, CAST(COUNT(h.MatrNr) AS real) / (SELECT COUNT(*) FROM STUDENTEN) AS Marktanteile
FROM Vorlesungen v
LEFT OUTER JOIN hoeren h ON h.VorlNr = v.VorlNr
GROUP BY v.VorlNr;
```

```sql
WITH GesamtBesetzung AS (
  SELECT Fakultaet, count(*) AS gesamt
  FROM Studenten
  GROUP BY Fakultaet
), WeiblicheBesetzung AS (
  SELECT Fakultaet, count(*) AS weiblich
  FROM Studenten
  WHERE Geschlecht = "w"
  GROUP BY Fakultaet
)
SELECT w.Fakultaet, coalesce(CAST(weiblich AS REAL), 0) / gesamt AS Frauenquote
FROM WeiblicheBesetzung w
RIGHT OUTER JOIN GesamtBesetzung g ON w.Fakultät=b.Fakultät;
```
