ReMindful
=========

## Design

### Functionality

A timer, based on one of:
- Periodic: based off top of the hour: every minutes or hours
- Random: based on interval of 'minimum' to 'maximum' minutes or hours

When timer fires:
- Select a random text item from configured list
    - list is configurable
    - backend storage? TBD
- Play bell sound
    - bell is configurable
    - bell can be uploaded into app

Quiet Period
- Start time (time of day, default: 9pm)
- End time (time of day, default: 8am)

Controls:
- enable/disable
- mute

### Configuration:

- Timer:
    Selection, one of:
        - Periodic
            - Interval (minutes or hours) 
        - Random
            - Minimum (minutes or hours)
            - Maximum (minutes or hours)
- Enabled
- Mute
- Reminders
    - a list of text items
    - how to store?
        - https://flutter.dev/docs/cookbook/persistence/key-value
    - this could be it's own widget
- Bell
    - A list of bells
    - Add new bell (tag as user-added)
    - Delete bell
        - Do not allow deletion of default bells
- Quiet Period
    - Start time (time of day, default: 9pm)
    - End time (time of day, default: 8am)
    - Set to same time to disable

## UI

### Main Screen
```
+--------------------------------------------+
|===       (layout: Container)               |
|  +--------------------------------------+  |
|  |                                      |  |
|  |  Reminder text                       |  |
|  |  (layout: Center)                    |  |
|  |                                      |  |
|  |                                      |  |
|  |                                      |  |
|  +--------------------------------------+  |
|                                            |
|                                            |
|   <slider> Enabled      <slider> Mute      |
|                                            |
|   Next reminder at: HH:MM (small font)     |
+--------------------------------------------+
```

### Configuration Menu

```
+--------------------------------------------+
|                                            |
|   <slider> Enabled      <slider> Mute      |
|                                            |
|  +--------------------------------------+  |
|  |  Schedule + Quiet Period             |  |
|  +--------------------------------------+  |
|  +--------------------------------------+  |
|  |  Reminders                           |  |
|  +--------------------------------------+  |
|  +--------------------------------------+  |
|  |  Bells                               |  |
|  +--------------------------------------+  |
|                                            |
|  +--------------------------------------+  |
|  |  Advanced                            |  |
|  +--------------------------------------+  |
+--------------------------------------------+
```

#### Schedule - Periodic

Periodic selected via Slider

```
+--------------------------------------------+
|  Schedule                                  |
|                                            |
|  Periodic <<<slider> Random                |
|                                            |
|  +--------------------------------------+  |
|  |                                      |  |
|  | Interval:  _01_:_00_  Hours:Minutes  |  |
|  |                                      |  |
|  +--------------------------------------+  |
|                                            |
| Quiet Hours:                               |
|                                            |
+--------------------------------------------+
```

#### Schedule - Random

Random selected via Slider

```
+--------------------------------------------+
|  Schedule                                  |
|                                            |
|  Periodic <slider>>> Random                |
|                                            |
|  +--------------------------------------+  |
|  | Minimum:  _00_:_45_  Hours:Minutes   |  |
|  | Delay                                |  |
|  |                                      |  |
|  | Maximum:  _01_:_30_  Hours:Minutes   |  |
|  | Delay                                |  |
|  +--------------------------------------+  |
|                                            |
| Quiet Hours:                               |
|                                            |
+--------------------------------------------+
```

#### Schedule - Quiet Hours
```
+--------------------------------------------+
|  Schedule:                                 |
|                                            |
|  Periodic <slider>>> Random                |
|                                            |
|  +--------------------------------------+  |
|  | Minimum:  _00_:_45_  Hours:Minutes   |  |
|  | Delay                                |  |
|  |                                      |  |
|  | Maximum:  _01_:_30_  Hours:Minutes   |  |
|  | Delay                                |  |
|  +--------------------------------------+  |
|                                            |
| Quiet Hours:                               |
|                                            |
|  +--------------------------------------+  |
|  | Quiet:  _09_:_00_ PM  Time Picker    |  |
|  | Start             --  (dropdown)     |  |
|  |                                      |  |
|  | Resume: _08_:_00_ AM  Time Picker    |  |
|  |                   --  (dropdown)     |  |
|  +--------------------------------------+  |
|                                            |
+--------------------------------------------+
```

#### Reminders

- Select Reminder:
    - Edit
    - Long Press to delete
        - with confirmation
- Add Button bottom right

```
+--------------------------------------------+
|  Reminders                                 |
|                                            |
|  +--------------------------------------+  |
|  | Text1                                |  |
|  +--------------------------------------+  |
|  | Text2                                |  |
|  +--------------------------------------+  |
|  | Text3                                |  |
|  +--------------------------------------+  |
|  | Text4                                |  |
|  +--------------------------------------+  |
|  | Text5                                |  |
|  +--------------------------------------+  |
|                                            |
|                                      ----- |
|                                      | + | |
|                                      ----- |
+--------------------------------------------+
```

#### Bell

- Select bell
    - Play bell
    - Long Press to delete
        - with confirmation
- Add Button bottom right

```
+--------------------------------------------+
|  Bell                                      |
|  Select the bell                           |
|  Long-press for option (delete)            |
|                                            |
|  +--------------------------------------+  |
|  | None                                 |  |
|  +--------------------------------------+  |
|  | Bell1                                |  |
|  +--------------------------------------+  |
|  | Bell2                                |  |
|  +--------------------------------------+  |
|  | Bell3                                |  |
|  +--------------------------------------+  |
|                                            |
|                                      ----- |
|                                      | + | |
|                                      ----- |
+--------------------------------------------+
```
#### Advanced

```
+--------------------------------------------+
|   Revert to Defaults                       |
|   Import                                   |
|   Export                                   |
+--------------------------------------------+
```
