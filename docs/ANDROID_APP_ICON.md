# Android launcher icon (adaptive safe zone)

We use `ic_launcher_foreground_inset.xml` so the full logo + text fits inside the adaptive icon safe zone and is not clipped by circular/squircle masks.

**If you run `dart run flutter_launcher_icons` again**, it may reset `mipmap-anydpi-v26/ic_launcher.xml` to point directly at `@drawable/ic_launcher_foreground`.  
After regenerating, change the foreground line back to:

```xml
<foreground android:drawable="@drawable/ic_launcher_foreground_inset"/>
```

Or increase/decrease the `18dp` insets in `drawable/ic_launcher_foreground_inset.xml` if the icon still feels too tight or too small.
