ReMindful
=========

Functionality

A timer, based on one of:
- Periodic: based off top of the hour: every minutes or hours
- Random: based on interval of 'minimum' to 'maximum' minutes or hours

When timer fires:
- select a random text item from configured list
    - list is configurable
    - backend storage? TBD
- Play bell sound
    - bell is configurable
    - bell can be uploaded into app

Controls:
- enable/disable
- mute

Configuration:
- Timer:
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
    - this could be it's own widget

```
+--------------------------------------------+
|===                                         |
|  +--------------------------------------+  |
|  |                                      |  |
|  |  Reminder text                       |  |
|  |                                      |  |
|  |                                      |  |
|  |                                      |  |
|  |                                      |  |
|  +--------------------------------------+  |
|                                            |
|                                            |
|   <slider> Enabled      <slider> Mute      |
|                                            |
+--------------------------------------------+
```
