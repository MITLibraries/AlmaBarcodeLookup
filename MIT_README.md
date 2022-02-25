# Alma Barcode Lookup Addon with LSA holds

## Summary
Adds functionality to Illiad to place holds on items in Alma. Intended to support LSA Scan & Deliver service. 

## Settings
additional settings
> **User Primary ID:** The Alma Primary Identified of the user for whom holds will be placed.
>
> **office delivery:** Overrides the location code setting. a flag to indicate that the user's office location should be used as the pickup location. 
>
> **location code for hold shelf:** The Alma Location code for the hold shelf where holds should be delivered. Not applicable for if Office Delivery is selected.
>


## Buttons
A **"Place LSA Hold"** button has been added to the addon's ribbon. 

## Notes / To Do
* Currently, the **Place LSA Hold** function takes the barcode from the same illiad field defined for **Import by barcode** function. 
* Scan and deliver requests for books are made at the title level and do not have a barcode. Logic should be included to use either a barcode or MMS ID to place the hold. 