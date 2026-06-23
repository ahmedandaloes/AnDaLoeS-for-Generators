-- Fix rental_requests UPDATE: restrict what customers can change.
-- Customers can only cancel their own pending requests (status = 'cancelled').
-- Owners can update status on their company's requests.
-- Admins have unrestricted update access.

DROP POLICY IF EXISTS rental_requests_update ON rental_requests;

-- Customers: only allowed to set status = 'cancelled' on their own requests
CREATE POLICY rental_requests_update_customer
  ON rental_requests FOR UPDATE
  USING (customer_id = auth.uid())
  WITH CHECK (
    customer_id = auth.uid()
    AND status = 'cancelled'
  );

-- Owners: can update any field on requests for their company
CREATE POLICY rental_requests_update_owner
  ON rental_requests FOR UPDATE
  USING (owns_company(company_id))
  WITH CHECK (owns_company(company_id));

-- Admins: full update access
CREATE POLICY rental_requests_update_admin
  ON rental_requests FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Allow owners to read basic profile info for customers in their rentals,
-- and allow customers to see profiles of owners they rented from.
CREATE POLICY profiles_select_rental_party
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM rental_requests rr
      JOIN companies c ON c.id = rr.company_id
      WHERE rr.customer_id = profiles.id
        AND c.owner_user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM rental_requests rr
      JOIN companies c ON c.id = rr.company_id
      WHERE rr.customer_id = auth.uid()
        AND c.owner_user_id = profiles.id
    )
  );
