# Privacy Policy — Mast UI

**Effective Date: 31 July 2026**

Thank you for using Mast UI ("the App"). This Privacy Policy explains how your
information is handled when you use our application.

## 1. Information We Collect

Mast UI lets you browse UI design inspiration, copy prompts, and generate an AI
prompt from a screenshot you upload.

You do not need an account to use the App. We do not collect your name, email
address, phone number, home address, or passwords.

We do process the following:

- **A random device identifier.** When you first open the App, we generate a
  random ID and store it on your device. It is not derived from your hardware,
  your account, or your advertising ID, and it cannot be traced back to you. Its
  only purpose is to count how many prompt generations a device has used today.
- **Screenshots you choose to upload** to the prompt generator (see Section 3).
- **In-app activity**, such as which designs are viewed, copied, or downloaded,
  and what is typed into the search box (see Section 5).

## 2. Purchases and Subscriptions

Mast UI Pro is a paid subscription (and a one-time Lifetime option).

- Payments are processed entirely by **Google Play** or the **Apple App Store**.
  We never see or store your card number, billing address, or payment details.
- We use **RevenueCat** to check whether your purchase is active so the App can
  unlock Pro features. RevenueCat receives an anonymous app user ID, your
  purchase receipt, and basic device and country information from the store.
- To cancel or change your plan, use the subscription settings in Google Play or
  the App Store. Deleting the App does not cancel a subscription.

RevenueCat's privacy policy: https://www.revenuecat.com/privacy/

## 3. Screenshot to Prompt (AI Feature)

When you use the "Screenshot to prompt" feature, the image you select is
uploaded to our server (running on Cloudflare Workers) and passed to an AI
vision model (Cloudflare Workers AI) which describes the interface so we can
build a prompt from it.

- **The uploaded image is not stored.** It is held in memory only for as long as
  the model needs to read it, then discarded.
- We do keep a small record of the request — the random device ID, the date, the
  target platform you chose, and the detected style name — so we can enforce the
  daily limit and detect abuse. This record contains no image and no personal
  information.
- Do not upload screenshots containing personal, confidential, or sensitive
  information. You are responsible for what you choose to upload.

Cloudflare's privacy policy: https://www.cloudflare.com/privacypolicy/

## 4. Advertising

The free version of the App displays advertisements using **Google AdMob**. Ads
are not shown to Mast UI Pro subscribers.

Google AdMob may automatically collect certain information to provide and
improve advertising services, including device information, advertising ID, IP
address, app interactions, and diagnostic information. This information is
collected by Google in accordance with its own privacy policy.

- https://policies.google.com/privacy
- https://support.google.com/admob

You can reset or delete your advertising ID in your device settings.

## 5. Analytics

We collect basic, non-identifying usage events to understand which designs are
popular and improve the catalogue. These events record the design ID, its
category, the type of interaction (view, copy, download, or how long a design
was on screen), and search terms typed into the App.

These events are not linked to your device identifier or to any account, and are
used only in aggregate. Search terms are stored as typed — please do not enter
personal information into the search box.

## 6. Data Storage and Retention

Data is stored on **Cloudflare** infrastructure (Workers and R2 object storage).

- Daily usage counters are keyed by date and expire naturally as they stop being
  read; they hold only a count.
- Request metadata and analytics events are retained for up to 12 months.
- We do not sell your data or share it with advertisers beyond the ad service
  described in Section 4.

## 7. Third-Party Services

The App uses the following third-party services, each operating under its own
privacy policy:

| Service | Purpose |
|---|---|
| Google AdMob | Advertising (free users only) |
| Google Play Billing / Apple App Store | Payment processing |
| RevenueCat | Subscription status |
| Cloudflare (Workers, Workers AI, R2) | Backend, AI prompt generation, storage |

## 8. Children's Privacy

Mast UI is not intended for children under the age of 13. We do not knowingly
collect personal information from children. If you believe a child has provided
personal information through the App, please contact us so we can take
appropriate action.

## 9. Data Security

We take reasonable measures to provide a secure application experience. All
communication between the App and our server uses HTTPS. However, no method of
electronic transmission or storage is completely secure, and we cannot guarantee
absolute security.

## 10. Your Rights

Because Mast UI does not create user accounts, we hold very little data about
you and nothing that identifies you personally.

If you would like the usage records associated with your device removed, email
us the request and we will delete them. You can also clear the App's storage or
uninstall the App, which removes the random device identifier from your device.

For data held by Google, Apple, or RevenueCat in connection with a purchase,
please contact those services directly.

## 11. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Any changes will be posted
on this page with a revised Effective Date. Continued use of the App after
changes become effective constitutes acceptance of the updated policy.

## 12. Contact Us

**Developer:** Sanju Yadav
**Email:** sanjeev.yadav1201@gmail.com
