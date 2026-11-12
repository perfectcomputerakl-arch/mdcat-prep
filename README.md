# MDCAT Prep (Flutter)

## Chalane ke steps
1. Flutter install karein: https://docs.flutter.dev/get-started/install
2. Terminal mein: `flutter create mdcat_prep`
3. Is folder ki teeno cheezein (`pubspec.yaml`, `lib/main.dart`, `assets/questions.json`) naye project mein copy karke purani files replace kar dein.
4. `flutter pub get` phir `flutter run`

## Zyada MCQs add karna
`assets/questions.json` mein har subject ki list mein naye sawal paste karein. Code badalne ki zaroorat nahi.
Format: `q` sawal, `o` 4 options, `a` sahi option (0 se shuru), `e` explanation, `t` chapter.

## Premium (Google Play Billing)
1. Google Play Developer account banayein (one-time $25 fee).
2. Play Console mein app banayein, phir 2 subscriptions banayein: `premium_monthly` aur `premium_yearly`.
3. App ko Internal testing track par upload karein aur apna Gmail tester ke tor par add karein. Billing sirf Play Store se install ki hui app mein chalti hai.
4. Launch se pehle purchase ki tasdeeq (verification) server par karwayein. Abhi app sirf device par check karti hai.

## Play Store ke liye build
`flutter build appbundle` (file `build/app/outputs/bundle/release/` mein banti hai)
App icon, package name (`com.yourname.mdcatprep`) aur signing key bhi set karni hogi.

## Abhi shamil nahi
- Urdu interface (web demo mein tha). Flutter mein `flutter_localizations` se add hoga.
- Content: abhi sirf 12 sample MCQs hain, web demo wale 32 MCQs yahan copy kar sakte hain.
