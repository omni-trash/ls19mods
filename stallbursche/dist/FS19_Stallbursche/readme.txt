1.20.1.19
- first release

1.20.4.10
- checking pallets added (eggs, wool)

1.20.8.16
- checking reproduction available now works as expected, even the husbandry is full

1.20.8.24
- message keys are now unique for each husbandry (multiple husbandries of same animal)
- the ingame notification contains now the position (direction, degrees, distance and field number)
  of the husbandry, where the message comes from, in relation to the current player position.
  hope that helps to identify the hotspot, if multiple husbandries of same animals are present.
  use the ingame map to verify the compass direction (N, NE, E, SE, S, SW, W and NW).
  the strings are in the modDesc.xml, feel you free to modify them.
  but for now only the field number is shown. You can change that by replace {positionInfo} 
  with {positionInfoDetails} in the modDesc.xml on INGAME_NOTIFICATION.
