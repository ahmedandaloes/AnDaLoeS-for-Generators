-- Records the physical state of the generator at delivery and return.
-- Separate from rental_timeline_events (which tracks status transitions);
-- this captures the operational check-in/check-out data.

CREATE TABLE IF NOT EXISTS rental_handovers (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rental_id      uuid NOT NULL REFERENCES rental_requests(id) ON DELETE CASCADE,
  type           text NOT NULL CHECK (type IN ('delivery', 'return')),
  fuel_level     text CHECK (fuel_level IN ('full','three_quarters','half','quarter','empty')),
  meter_reading  numeric(12, 1),
  note           text,
  recorded_by    uuid REFERENCES auth.users(id),
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (rental_id, type)
);

CREATE INDEX idx_handovers_rental ON rental_handovers(rental_id);

ALTER TABLE rental_handovers ENABLE ROW LEVEL SECURITY;

-- Owner (company member) may insert handovers for their rentals.
CREATE POLICY handovers_insert_owner
  ON rental_handovers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM rental_requests rr
      JOIN companies c ON c.id = rr.company_id
      WHERE rr.id = rental_id
        AND c.owner_user_id = auth.uid()
    )
  );

-- Both parties (customer + owner) can read handovers for their rental.
CREATE POLICY handovers_select_parties
  ON rental_handovers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rental_requests rr
      JOIN companies c ON c.id = rr.company_id
      WHERE rr.id = rental_id
        AND (rr.customer_id = auth.uid() OR c.owner_user_id = auth.uid())
    )
  );

-- Admins can read and insert everything.
CREATE POLICY handovers_admin
  ON rental_handovers FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());
