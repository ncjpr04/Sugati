# Communication Hub Inbound Email Setup

This guide covers org configuration required after deploying the inbound messaging Apex classes and Email Service metadata.

## Overview

Outbound emails from the Communication Hub set `Reply-To: b221519@skit.ac.in`. Replies to that address must be forwarded into Salesforce Email Service, which runs `SugatiCommunicationInboundEmailHandler` to create inbound `Comm_Log__c` records threaded to the original outbound message.

## 1. Email Service run-as user

The Email Service metadata uses `shivamm@aptclouds.com.sugdevext` as `runAsUser` for the dev org (Salesforce **username**). Gmail verification notifications are sent to that user's **Email** field (`shivamm@aptclouds.com`). For other orgs, update [`force-app/main/default/emailservices/Comm_Hub_Inbound.xml`](../force-app/main/default/emailservices/Comm_Hub_Inbound.xml) to the integration user's username before deploy.

That user needs:

- Create/read/edit on `Comm_Log__c` and `Comm_Recipient__c`
- Create files (`ContentVersion`, `ContentDocumentLink`)

Deploy the handler, service, and email service metadata together.

## 2. Activate the Email Service

1. In Setup, search for **Email Services**.
2. Open **Comm_Hub_Inbound**.
3. Confirm the service is active.
4. Open the **comm_hub_inbound** email address.
5. Copy the full generated address (format: `commhubinbound@<unique>.salesforce.com`).

## 3. Forward replies from the Reply-To mailbox

Configure `b221519@skit.ac.in` to automatically forward all received messages to the Salesforce Email Service address from step 2.

Typical mailbox setup:

1. Sign in to the `b221519@skit.ac.in` mailbox.
2. In Gmail: **Settings** → **Forwarding and POP/IMAP** → **Add a forwarding address** → paste the Salesforce address from step 2.
3. Gmail sends a **verification email to the Salesforce address** (not to your inbox). The inbound handler captures it automatically.
4. Complete verification using one of these:
   - Check `shivamm@aptclouds.com` (Email on user `shivamm@aptclouds.com.sugdevext`) for **Comm Hub: Gmail forwarding verification link**
   - In Salesforce, open the newest `Comm_Log__c` with `Delivery_Mode__c = mailbox_verification` and click **Open verification link** in the body
   - In Setup → **Debug Logs**, search for `MAILBOX_FORWARDING_VERIFICATION` and copy `verificationUrl=`
5. After Gmail shows the address as verified, enable **Forward a copy of incoming mail to** that Salesforce address.
6. Keep a copy in the mailbox if your provider supports it (optional, for troubleshooting).

## 4. End-to-end verification

1. Send an outbound email from the Communication Hub on a test Opportunity (Postmark or Native mode).
2. Confirm the sent email header includes `Reply-To: b221519@skit.ac.in`.
3. Reply from one of the original recipient addresses.
4. Wait for forwarding and Email Service processing.
5. In Salesforce, verify:
   - A new `Comm_Log__c` exists with `Direction__c = Inbound` and `Status__c = Received`
   - `Parent_Comm_Log__c` points to the original outbound log
   - `Comm_Recipient__c` on the inbound log matches the sender and copies `Contact__c` from the parent recipient when the email matches
   - The inbound message appears in Communication History on the Opportunity
6. Reply again with the same inbound `Message-Id` forwarded twice and confirm only one inbound log is created.

## Required org fields

These fields must be deployed before inbound processing works:

- `Comm_Log__c.Message_Id__c` — used to match inbound `In-Reply-To` / `References` to the parent outbound log
- `Comm_Recipient__c.Message_Id__c` — used on outbound sends for Postmark/webhook correlation (not for inbound parent matching)

`Comm_Log__c.From_Address__c` is used for **outbound** sends only. Inbound sender details live on `Comm_Recipient__c`, not on the inbound `Comm_Log__c`.

## Inbound processing flow

1. Read `In-Reply-To` / `References` from the received email.
2. Match that value to `Comm_Log__c.Message_Id__c` on an existing outbound log.
3. Create a new inbound `Comm_Log__c` with `Parent_Comm_Log__c` pointing to the matched log.
4. Compare the received email `fromAddress` with the parent log's `Comm_Recipient__c.Email_Address__c` rows.
5. Create one `Comm_Recipient__c` on the inbound log using the matched parent recipient's:
   - `Email_Address__c`
   - `Contact__c` (if present)
   - `Phone_Number__c` (if present)
   - `Name`
   - `Recipient_Type__c`
   - `Status__c = Inbound`
6. Do not copy other recipient fields such as `Email_Send_Type__c`, `Message_Id__c`, or tracking timestamps.

## Troubleshooting

| Symptom | Check |
|---|---|
| Gmail forwarding stuck on "Verify" | Click **Re-send email** in Gmail, then check run-as user inbox or `Comm_Log__c` where `Delivery_Mode__c = mailbox_verification` for the verification link |
| No inbound log created | Confirm email reached Salesforce Email Service (Setup → Email Services → Comm_Hub_Inbound). Parent match requires `In-Reply-To` or `References` to match `Comm_Log__c.Message_Id__c` on an outbound log |
| Email Service not invoked | Forwarding rule on `b221519@skit.ac.in` to the `commhubinbound@...salesforce.com` address |
| Handler error / no DML | `runAsUser` permissions, required fields deployed, debug logs for `SugatiCommunicationInboundService` |
| Parent not matched | Resend a **new** outbound email so `Message_Id__c` is populated, then reply to that message |
| Duplicate logs | Inbound deduplication uses inbound `Message-Id`; verify mail server is not generating new IDs on forward |

## Out of scope in this release

- Inbound emails with no matching parent Comm Log are ignored
- Reply-To is hardcoded to `b221519@skit.ac.in` in `SugatiCommunicationHubController`
