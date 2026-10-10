# Play Console — Data safety form answers (draft)

Answers reflect what the code does today. **You are legally responsible for the final declaration**; re-check it
against the build you upload. If you enable Twilio/Firebase/SMTP, the "shared" answers below change.

## Overview
| Question | Answer |
|---|---|
| Does the app collect or share any required user data types? | Yes |
| Is all collected data encrypted in transit? | Yes (HTTPS required by release build) |
| Do you provide a way for users to request deletion? | Yes — in-app deactivation + web page `account-deletion.html` |
| Is data processed ephemerally? | No |

## Data types
| Category | Type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|---|
| Personal info | Name | Yes | No | App functionality, account management | No |
| Personal info | Email address | Yes | No (**Yes** with SMTP provider for reset emails: service provider processing) | Account management | No |
| Personal info | Phone number | Yes | Emergency contacts' numbers are sent to SMS provider only if enabled | App functionality | Yes |
| Health and fitness | Health info (allergies, conditions, blood group, notes, medications) | Yes | No | App functionality | Yes |
| Location | Approximate / precise location | Yes, only when the user sends an emergency request | Shared with hospital staff operating the queue (and in SMS map link if enabled) | App functionality | Yes |
| App activity | Other user-generated content (records, appointments) | Yes | No | App functionality | Yes |
| App info and performance | Crash logs / diagnostics | **No** (no crash SDK) | — | — | — |
| Device or other IDs | Push token | Only if Firebase configured | Google (FCM) as service provider | App functionality | Yes |

Not collected: financial info, contacts list, messages, photos/videos, audio, web history, advertising ID.

## Security practices
* Encrypted in transit: yes. * Users can request data deletion: yes.
* Independent security review: **no** (do not tick).
* Follows Families policy: no (not directed at children; set target audience 18+).

## Health apps declaration (App content → Health apps)
Select "Medical" functions truthfully: appointment booking, health records, medication reminders, emergency
requests. State that the app is **not** a medical device and gives no diagnosis. If Play asks for regulatory
status, answer that it has not been assessed.
