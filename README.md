# Shoehorn
Dynamic content registration utility for PMD: Origins

## About
Shoehorn is a mod for PMD: Origins that allows dynamic ID assignment to:
- Monsters
- Skills / Moves
- Elements
- Items
- Intrinsics / Abilities

Essentially, this means that you can add any monster you want to the game, or even alter existing ones, using this mod.

## How does it work?
All changes must be registered using Shoehorn Packs. These are folders placed within *any mod*, in a top-level `Shoehorns` folder.
Each pack requires a `.shoehorn` file which includes a name, authors, a description, and registration data for everything you want to add.
You can also include compatibility data for certain quests!

## For Development - The TODO List:
- [ ] Item Registration
- [ ] Intrinsics Registration
- [ ] Monster Learnset ID Adjustment
- [ ] Monster Intrinsic ID Adjustment
- [ ] Skill Element ID Adjustment
- [ ] Zone Monster Registration & Adjustment
- [ ] Zone Item Registration & Adjustment
- [ ] `.jsonpatch` Shoehorn Support