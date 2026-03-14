# 📸 Image Setup Guide for Scraps App

## 🎯 Required Images

You need to create the following image files in the `assets/` folder:

### 1. **scraps.png** (Main Logo)
- **Size**: 512x512px (or higher)
- **Format**: PNG with transparency
- **Usage**: Main app logo, onboarding screen
- **Description**: Your main app logo/icon

### 2. **scraps_icon.png** (Small Icon)
- **Size**: 64x64px to 128x128px
- **Format**: PNG with transparency
- **Usage**: App bar, drawer, small UI elements
- **Description**: Smaller version of your logo for UI elements

### 3. **scraps_splash.png** (Splash Screen)
- **Size**: 512x512px (or higher)
- **Format**: PNG with transparency
- **Usage**: Splash screen, large displays
- **Description**: High-quality version for splash screen

### 4. **scraps_logo.png** (Alternative Logo)
- **Size**: 256x256px to 512x512px
- **Format**: PNG with transparency
- **Usage**: Alternative logo version
- **Description**: Backup or alternative logo design

## 📁 File Structure
```
assets/
├── ecg_logo.png          (old logo - can be removed)
├── scraps.png            (main logo - 512x512px)
├── scraps_icon.png       (small icon - 64x64px)
├── scraps_logo.png       (alternative logo - 256x256px)
└── scraps_splash.png     (splash logo - 512x512px)
```

## 🎨 Design Guidelines

### **Square Design with Rounded Corners**
- All images should be square (1:1 aspect ratio)
- Use rounded corners (8px to 20px radius)
- Ensure content is centered and properly scaled

### **Color Scheme**
- Use your brand colors
- Ensure good contrast against blue backgrounds
- Consider both light and dark theme compatibility

### **Content Requirements**
- Make sure the logo content is clearly visible
- Avoid text that's too small to read
- Use high contrast colors for better visibility

## 🔧 Current Implementation

The app now uses a smart image system:

### **Context-Based Image Selection**
- **Splash Screen**: Uses `scraps_splash.png` (120x120px)
- **Onboarding**: Uses `scraps.png` (180x180px)
- **Dashboard Drawer**: Uses `scraps_icon.png` (60x60px)
- **App Bar**: Uses `scraps_icon.png` (32x32px)

### **Error Handling**
- If images are missing, the app shows fallback icons
- Graceful degradation ensures the app still works
- Debug information helps identify missing images

## 🚀 Next Steps

1. **Create the required image files** with the specified dimensions
2. **Place them in the `assets/` folder**
3. **Test the app** to see how they look
4. **Adjust dimensions** if needed for better visual appearance

## 🐛 Troubleshooting

### **Images Not Showing?**
- Check file names match exactly (case-sensitive)
- Ensure images are in the `assets/` folder
- Run `flutter clean` and `flutter pub get`
- Check console for error messages

### **Images Too Small/Large?**
- Adjust the dimensions in the code
- Use different image files for different contexts
- Consider using vector images (SVG) for scalability

### **Performance Issues?**
- Optimize image file sizes
- Use appropriate formats (PNG for transparency, JPG for photos)
- Consider using WebP format for better compression

## 📱 Testing

After adding your images:
1. Run `flutter clean`
2. Run `flutter pub get`
3. Run `flutter run -d chrome`
4. Check all screens for proper image display
5. Test error handling by temporarily renaming image files

## 🎨 Design Tips

- **Keep it simple**: Clean, minimal designs work best
- **Test on different sizes**: Ensure logos look good at all sizes
- **Use consistent branding**: Same colors and style across all images
- **Consider accessibility**: High contrast and clear shapes
- **Think about the context**: How will it look on different backgrounds?

---

**Need help?** Check the console output for specific error messages about missing images!
