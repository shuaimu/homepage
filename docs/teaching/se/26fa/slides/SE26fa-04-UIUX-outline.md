# CSE 416 UI/UX lecture outline

September 21, 2026. A lecture driven by eleven UI examples, using the established Fall 2026 CSE 416 theme. The 21-slide deck ends with a bilingual contact-sorting comparison.

## Learning objectives

Describe a user’s task, identify what changes between two interfaces, explain a possible tradeoff, and propose an observation that could test a design change.

## Timed outline

| Time | Topic | Discussion focus |
| --- | --- | --- |
| 0–6 min | Learning through examples | Apply our common sense and explain our judgments |
| 6–10 min | Apple Liquid Glass: launch complaints and user control | How do transparency and readability interact? |
| 10–15 min | Accessibility Reader | Who benefits from a different reading view? |
| 15–19 min | Maps incident reporting | What do larger targets gain and cost? |
| 19–24 min | Android delivery notifications | What can the user infer about progress? |
| 24–28 min | Discord navigation reversal | When does cross-device consistency matter? |
| 28–33 min | Chrome suspicious-notification warning | How does a warning affect the next action? |
| 33–40 min | Instagram navigation | Reach, learned locations, and competing tasks |
| 40–45 min | Uber Eats confirmation | Waiting, confirming immediately, and Undo |
| 45–49 min | Airline resistive touch and iPhone capacitive touch | Pressure, feedback, and context |
| 49–52 min | Capacitive cooktop controls | How does the task change the design choice? |
| 52–57 min | Bilingual contact sorting | Interface language, Pinyin indexing, and setup burden |

## Presentation and comparison notes

The PDF contains 21 slides, one per page. Paired examples have a dedicated before slide followed by a dedicated after slide. Apple uses two slides: three beta 1 images side by side and a later transparency slider. Example pages 3–21 retain their titles, with no added labels, captions, questions, or citations. The teaching notes retain these cues and give page numbers for every comparison. Source acknowledgments remain in the notes and asset provenance files.

Apple opens with three beta 1 images side by side: Beto Moedano’s washed-out notifications, Holly’s cluttered Control Center, and Jay Peters’ beta 1 Control Center. The second Apple slide shows Apple’s iOS 27 transparency slider, announced at WWDC26. iOS 26.1 had already introduced binary Clear/Tinted options. The slider is a later example of user choice, not a direct after image for the notification complaint.

The screenshots depict documented historical releases, mode changes, and action states. Chrome’s warning comparison shows exposed content first for classroom discussion, then the protective view; the product itself shows the warning before the user reveals content. Android uses a sample application. Proposed usability benefits are hypotheses rather than measured results.

## Deliverables

- `SE26fa-04-UIUX.pdf`: presentation PDF with separate before and after slides.
- `SE26fa-04-UIUX.typ`: editable source; compile with `typst compile SE26fa-04-UIUX.typ`.
- `SE26fa-04-UIUX-notes.md`: teaching cues and before/after page numbers.
- `img/uiux/SOURCES.md`: screenshot provenance and exact source asset links.

## Uber Eats confirmation addition

One full phone screenshot from Robert Meza’s September 2023 post shows the Confirm countdown and Undo. Describe the documented 2020 progress-indicator-and-Undo state aloud before revealing this slide: its image could not be retrieved for embedding. The recovery window already existed. Discuss the added immediate-confirm option and timer clarity, alongside possible time pressure. The slide is a dated example; 15 seconds is not verified as a universal current default. Exact sources and teaching cues are in the notes.

## Replacement redesigns

The IBM, Spotify, and Airbnb examples have been removed. Pages 11–12 now show Discord’s December 2023 navigation and May 2024 reversal. Pages 15–16 show Instagram’s navigation before opting in and the layout announced in September 2025. These pairs use official release images or the responsible designer’s demonstration. Notes explain dates, source limitations, and tradeoffs. Exact links appear in the teaching notes and asset provenance files.

## Closing touch-interface sequence

Page 18 places an older Delta 737-800 seatback screen beside the original iPhone’s finger-typing illustration, under “Resistive touch vs capacitive touch.” Page 19 follows with the capacitive cooktop image. Titles and original image content remain on screen; technical distinctions and questions stay in the notes. These compare different products and environments. The notes distinguish reports about this older Delta screen style from verified hardware specifications and avoid generalizing to all airline screens. The kitchen photo does not document a failure. Teaching notes and asset provenance files acknowledge the images and technical sources.

## Bilingual contact sorting

Pages 20–21 show one screenshot each: historical iPhone Contacts with Chinese names grouped under “#,” then Android Contacts with Pinyin sections after phonetic-name setup. The Android title explicitly identifies setup. These sources do not establish default behavior across current iOS/Android versions. The lesson concerns language preferences and discoverable sorting controls. The notes document workarounds on both platforms and the source limitations.
