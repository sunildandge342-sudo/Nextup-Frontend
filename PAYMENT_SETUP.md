# NextUp – Razorpay payment gateway (Test Mode)

## How it works
1. Provider creates a service and (optionally) sets a **Queue Fee (₹)**. Empty / 0 = free service.
2. Customer scans the service QR. The app calls `POST /api/user/payment/create-order`.
   * Free service → app joins the queue as before.
   * Paid service → server creates a `PENDING` payment + Razorpay order and returns `orderId`, `amountPaise`, `keyId`.
3. App shows "Pay ₹X to join", then opens **Razorpay Checkout**.
4. On success the app calls `POST /api/user/payment/verify` with `razorpayOrderId`, `razorpayPaymentId`, `razorpaySignature`.
   The server checks the HMAC-SHA256 signature with the key secret, marks the payment `SUCCESS`, **then issues the queue token**.
5. Payment history: customer → *Account → Payments*; provider → *Account → Payments* (all payments for their services).

Security: the amount comes from the server (service fee), the key secret never reaches the app, the token is issued only after signature verification, and the paying user is taken from the JWT, not the request body. The old `/api/user/token/join` endpoint refuses paid services.

## Backend setup
Get **Test Mode** keys from Razorpay Dashboard → Settings → API Keys (`rzp_test_…`), then set environment variables on Render/Railway (or locally):

```
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx
```
The `payments` table and `services.fee` column are created automatically (`ddl-auto=update`).

## Endpoints
| Method | Path | Who |
|---|---|---|
| POST | `/api/user/payment/create-order` `{serviceId}` | USER |
| POST | `/api/user/payment/verify` | USER |
| POST | `/api/user/payment/failed` | USER |
| GET  | `/api/user/payment/history` | USER |
| GET  | `/api/payments/provider/{providerId}` | SERVICE_PROVIDER |
| POST | `/api/provider/services` now accepts `"fee"` | SERVICE_PROVIDER |

## Test cards / UPI (Razorpay Test Mode)
Card `4111 1111 1111 1111`, any future expiry, any CVV, OTP `1234`/any on the test bank page. UPI: `success@razorpay` (success) or `failure@razorpay` (failure).

## Build the APK
Local: `flutter pub get && flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
Cloud: push to GitHub and run **Actions → Build NextUp APK** (`.github/workflows/build-apk.yml`), then download the `nextup-apk` artifact.
The release APK is signed with the debug key; create a real keystore before publishing to the Play Store.
