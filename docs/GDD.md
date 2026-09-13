# Rogue's Journal — Game Design Document

**Working title:** Rogue's Journal  
**Genre:** First-person narrative RPG / choice adventure  
**Perspective:** First person, framed as a journal written in the hours before and during the king's feast  
**Setting:** A small, rain-rotten medieval kingdom. One castle. One bad night.  
**Tone:** Dark, muddy, torchlit. Comedy is dry, not cartoon.  
**Target look:** 16-bit SNES-era pixel scenes (not a 3D shooter). First-person presentation: illustrated view + journal text.

## One-sentence pitch

You write your way across a kingdom to a feast where the king is showing off the woman he stole from you — and every page of the journal is a choice of steel, shadow, tongue, or spark.

## Player fantasy

You are not a chosen hero. You are a competent, slightly unwell person with a knife, a few coins, and a reason. The fantasy is getting in, not saving the realm.

## Core loop

1. Arrive at a place (road, inn, gate, kitchen, gallery, hall).
2. Read the journal entry describing what you see.
3. Pick an approach (or mix two).
4. Spend or risk a resource (Heat, Coin, Nerve, Rumor).
5. Get a consequence that changes the next room — not just flavor text.
6. Write the next page.

## Approaches

These are not exclusive classes. They are meters that grow as you use them.

| Approach | Verb | Fail-forward |
|---|---|---|
| **Steel** | Fight, intimidate, endure | You win ugly. Blood, noise, Heat. |
| **Shadow** | Steal, sneak, pick, vanish | You get in. Someone notices later. |
| **Tongue** | Lie, charm, bargain, name-drop | They believe you. The lie grows teeth. |
| **Spark** | Hedge-magic, charms, forbidden scraps | It works. Something else hears you. |

## Resources

- **Nerve** — composure. Hits 0 and choices get worse.
- **Heat** — how badly the castle wants you dead.
- **Coin** — bribes, rooms, bad wine.
- **Rumor** — social ammunition at the feast.
- **Token** — one-shot items (servant's key, invitation seal).

## Structure

**Act I — The Road to the Feast** (prototype): village → road → toll/inn → outer wall.  
**Act II — Inside:** kitchens, chapel, guest wing, gallery.  
**Act III — The Party:** confront the king. The wife speaks. Multiple endings.

## Confrontation (design)

King Aldric is vain, bored, and louder than he is dangerous. Mara Venn is an actor in the climax, not a package. She may already have a plan.

## Fail-forward

No dead ends in Act I–II. Game-over only if you force a public disaster in the hall with no exit.

## Presentation

Each scene: pixel illustration + journal page + 2–4 choices + thin HUD (Nerve / Heat / Coin / four approach pips).

## Scope lock for v0

One kingdom, one night, one feast. Four approaches. Playable Act I in HTML. No multiplayer, crafting, or 3D horse physics.
