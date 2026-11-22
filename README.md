# GingerBooks

Offline operations app for a small ginger candy manufacturer. It is a single HTML file: no installation, no server and no internet connection needed. Open `GingerBooks.html` in Chrome or Edge.

## Features
- GST tax invoices (CGST/SGST or IGST chosen automatically), printable to PDF; pricing by rate, discount % or margin % over cost; default discount per customer
- Purchases with batch, manufacture and expiry dates; production runs that consume raw materials (bill of materials) and record batch cost
- Sales returns (credit notes) and purchase returns (debit notes)
- Pending orders / backlog; demand vs supply with make/buy suggestions
- Stock by batch with FEFO picking; alerts for negative stock, zero batches, expired or expiring stock, low stock, sales below cost, dead stock, overdue dues and uncleared cheques
- Payments received by UPI, cheque, DD, cash, NEFT or card, with dues ageing
- Bank statement import (CSV / XLSX) that matches entries to receipts and invoices and turns debits into expenses
- Expenses: OpEx and CapEx, Fixed or Variable, with 60+ categories (labels, packing, dryer AMC, salaries…); vendors master
- Profit & loss, break-even analysis and a what-if calculator
- Analysis of customers, suppliers and vendors
- GSTR-1 tables, GSTR-3B summary, registers, all exportable as CSV (Excel)

## Data
Entries are stored in the browser's IndexedDB on the device in use; the HTML file holds no data. Back up from Settings & backup, either with a manual download or an automatic backup file. See `docs/Owner-Guide.html`.

`index.html` is a copy of `GingerBooks.html`, so GitHub Pages can serve the app if it is enabled.
