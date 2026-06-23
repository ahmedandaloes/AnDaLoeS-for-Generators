-- Fix: accept/reject (and every status change) failed with
--   "column rental_request_id of relation notifications does not exist"
--
-- Root cause: TWO triggers fired AFTER UPDATE OF status on rental_requests:
--   1. on_rental_status_change      -> notify_customer_on_status_change()  [correct]
--        inserts notifications(user_id, type, title, body, data) and stores
--        rental_request_id inside the `data` jsonb column.
--   2. trg_rental_status_notifications -> notify_rental_status_change()    [broken]
--        inserts into a `rental_request_id` COLUMN that does not exist on the
--        notifications table (migration 0012 only has a `data` jsonb column).
--
-- The broken insert raised an error that rolled back the whole UPDATE, so the
-- owner could never accept/reject/activate/complete a request. Even if it had
-- worked, the two triggers would have produced duplicate notifications.
--
-- Resolution: drop the broken trigger + function (from migration 0017). The
-- correct trigger from migration 0012 remains and produces proper, deduped
-- notifications with rental_request_id carried in the `data` jsonb payload.

DROP TRIGGER IF EXISTS trg_rental_status_notifications ON rental_requests;
DROP FUNCTION IF EXISTS notify_rental_status_change();
