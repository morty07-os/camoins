BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('DRIVER', 'CUSTOMER', 'ADMIN');
CREATE TYPE account_status AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'SUSPENDED', 'BANNED');
CREATE TYPE verification_status AS ENUM ('NOT_SUBMITTED', 'PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED');
CREATE TYPE truck_type AS ENUM ('VAN', 'BOX_TRUCK', 'FLATBED', 'SEMI_TRAILER', 'REFRIGERATED', 'TANKER', 'PICKUP', 'OTHER');
CREATE TYPE truck_status AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');
CREATE TYPE document_type AS ENUM ('REGISTRATION', 'INSURANCE', 'INSPECTION', 'OWNERSHIP', 'OTHER');
CREATE TYPE document_status AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED');
CREATE TYPE trip_status AS ENUM ('DRAFT', 'PUBLISHED', 'FULL', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'EXPIRED');
CREATE TYPE shipment_status AS ENUM ('DRAFT', 'OPEN', 'MATCHED', 'BOOKED', 'PICKUP_PENDING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED');
CREATE TYPE booking_status AS ENUM ('REQUESTED', 'ACCEPTED', 'REJECTED', 'CANCELLED', 'PICKUP_CONFIRMED', 'IN_TRANSIT', 'DELIVERED', 'DISPUTED');
CREATE TYPE message_type AS ENUM ('TEXT', 'IMAGE', 'FILE', 'SYSTEM');
CREATE TYPE payment_status AS ENUM ('PENDING', 'AUTHORIZED', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED');
CREATE TYPE dispute_status AS ENUM ('OPEN', 'UNDER_REVIEW', 'RESOLVED', 'CLOSED');

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role user_role NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(32) NOT NULL UNIQUE,
  email VARCHAR(320) UNIQUE,
  password_hash TEXT NOT NULL,
  profile_image_url TEXT,
  status account_status NOT NULL DEFAULT 'PENDING_VERIFICATION',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ,
  CONSTRAINT users_email_not_blank CHECK (email IS NULL OR btrim(email) <> '')
);

CREATE TABLE driver_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
  license_number VARCHAR(100) NOT NULL UNIQUE,
  verification_status verification_status NOT NULL DEFAULT 'NOT_SUBMITTED',
  rating_average NUMERIC(3, 2) NOT NULL DEFAULT 0 CHECK (rating_average BETWEEN 0 AND 5),
  completed_trip_count INTEGER NOT NULL DEFAULT 0 CHECK (completed_trip_count >= 0),
  cancellation_count INTEGER NOT NULL DEFAULT 0 CHECK (cancellation_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE trucks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE RESTRICT,
  truck_type truck_type NOT NULL,
  plate_number VARCHAR(32) NOT NULL UNIQUE,
  max_weight_kg NUMERIC(12, 3) NOT NULL CHECK (max_weight_kg > 0),
  max_volume_m3 NUMERIC(12, 3) CHECK (max_volume_m3 IS NULL OR max_volume_m3 > 0),
  refrigerated BOOLEAN NOT NULL DEFAULT false,
  dimensions JSONB,
  description TEXT,
  status truck_status NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE truck_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_id UUID NOT NULL REFERENCES trucks(id) ON DELETE CASCADE,
  document_type document_type NOT NULL,
  file_url TEXT NOT NULL,
  status document_status NOT NULL DEFAULT 'PENDING',
  expiration_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_id UUID NOT NULL REFERENCES trucks(id) ON DELETE RESTRICT,
  origin_name TEXT NOT NULL,
  destination_name TEXT NOT NULL,
  origin_point GEOGRAPHY(POINT, 4326) NOT NULL,
  destination_point GEOGRAPHY(POINT, 4326) NOT NULL,
  route_geometry GEOGRAPHY(LINESTRING, 4326),
  departure_time TIMESTAMPTZ NOT NULL,
  estimated_arrival_time TIMESTAMPTZ,
  available_weight_kg NUMERIC(12, 3) NOT NULL CHECK (available_weight_kg >= 0),
  available_volume_m3 NUMERIC(12, 3) CHECK (available_volume_m3 IS NULL OR available_volume_m3 >= 0),
  max_detour_km NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (max_detour_km >= 0),
  status trip_status NOT NULL DEFAULT 'DRAFT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT trips_arrival_after_departure CHECK (estimated_arrival_time IS NULL OR estimated_arrival_time > departure_time)
);

CREATE TABLE trip_route_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  sequence_number INTEGER NOT NULL CHECK (sequence_number >= 0),
  point GEOGRAPHY(POINT, 4326) NOT NULL,
  place_name TEXT,
  UNIQUE (trip_id, sequence_number)
);

CREATE TABLE shipments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  pickup_name TEXT NOT NULL,
  delivery_name TEXT NOT NULL,
  pickup_point GEOGRAPHY(POINT, 4326) NOT NULL,
  delivery_point GEOGRAPHY(POINT, 4326) NOT NULL,
  weight_kg NUMERIC(12, 3) NOT NULL CHECK (weight_kg > 0),
  volume_m3 NUMERIC(12, 3) CHECK (volume_m3 IS NULL OR volume_m3 > 0),
  cargo_type VARCHAR(100) NOT NULL,
  description TEXT,
  pickup_time_start TIMESTAMPTZ,
  pickup_time_end TIMESTAMPTZ,
  required_truck_type truck_type,
  fragile BOOLEAN NOT NULL DEFAULT false,
  refrigerated_required BOOLEAN NOT NULL DEFAULT false,
  status shipment_status NOT NULL DEFAULT 'DRAFT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT shipments_pickup_window_valid CHECK (pickup_time_end IS NULL OR pickup_time_start IS NULL OR pickup_time_end >= pickup_time_start)
);

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE RESTRICT,
  shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE RESTRICT,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  driver_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE RESTRICT,
  agreed_price NUMERIC(14, 2) CHECK (agreed_price IS NULL OR agreed_price >= 0),
  currency CHAR(3) NOT NULL DEFAULT 'DZD',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  pickup_confirmed_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  status booking_status NOT NULL DEFAULT 'REQUESTED',
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, shipment_id)
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  message_type message_type NOT NULL DEFAULT 'TEXT',
  content TEXT,
  attachment_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at TIMESTAMPTZ,
  CONSTRAINT messages_payload_present CHECK (content IS NOT NULL OR attachment_url IS NOT NULL)
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
  reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  reviewee_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT reviews_different_users CHECK (reviewer_id <> reviewee_id),
  UNIQUE (booking_id, reviewer_id)
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(100) NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
  payer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  platform_fee NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (platform_fee >= 0 AND platform_fee <= amount),
  currency CHAR(3) NOT NULL DEFAULT 'DZD',
  provider VARCHAR(100),
  provider_reference VARCHAR(255) UNIQUE,
  status payment_status NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payments_different_parties CHECK (payer_id <> receiver_id)
);

CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
  opened_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  reason VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  status dispute_status NOT NULL DEFAULT 'OPEN',
  resolution TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  CONSTRAINT disputes_resolution_timestamp CHECK (resolved_at IS NULL OR resolved_at >= created_at)
);

CREATE INDEX trips_status_departure_idx ON trips (status, departure_time);
CREATE INDEX trips_truck_id_idx ON trips (truck_id);
CREATE INDEX trips_origin_point_gix ON trips USING GIST (origin_point);
CREATE INDEX trips_destination_point_gix ON trips USING GIST (destination_point);
CREATE INDEX trips_route_geometry_gix ON trips USING GIST (route_geometry);
CREATE INDEX trip_route_points_point_gix ON trip_route_points USING GIST (point);
CREATE INDEX shipments_status_pickup_time_idx ON shipments (status, pickup_time_start);
CREATE INDEX shipments_customer_id_idx ON shipments (customer_id);
CREATE INDEX shipments_pickup_point_gix ON shipments USING GIST (pickup_point);
CREATE INDEX shipments_delivery_point_gix ON shipments USING GIST (delivery_point);
CREATE INDEX bookings_trip_status_idx ON bookings (trip_id, status);
CREATE INDEX bookings_customer_id_idx ON bookings (customer_id);
CREATE INDEX bookings_driver_id_idx ON bookings (driver_id);
CREATE INDEX messages_booking_created_idx ON messages (booking_id, created_at);
CREATE INDEX notifications_user_unread_idx ON notifications (user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX truck_documents_truck_status_idx ON truck_documents (truck_id, status);

CREATE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER driver_profiles_set_updated_at BEFORE UPDATE ON driver_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trucks_set_updated_at BEFORE UPDATE ON trucks FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trips_set_updated_at BEFORE UPDATE ON trips FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER shipments_set_updated_at BEFORE UPDATE ON shipments FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER bookings_set_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE FUNCTION validate_booking_status_transition() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF (OLD.status = 'REQUESTED' AND NEW.status IN ('ACCEPTED', 'REJECTED', 'CANCELLED'))
     OR (OLD.status = 'ACCEPTED' AND NEW.status IN ('PICKUP_CONFIRMED', 'CANCELLED', 'DISPUTED'))
     OR (OLD.status = 'PICKUP_CONFIRMED' AND NEW.status IN ('IN_TRANSIT', 'CANCELLED', 'DISPUTED'))
     OR (OLD.status = 'IN_TRANSIT' AND NEW.status IN ('DELIVERED', 'DISPUTED'))
     OR (OLD.status = 'DELIVERED' AND NEW.status = 'DISPUTED') THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid booking status transition from % to %', OLD.status, NEW.status
    USING ERRCODE = 'check_violation';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_validate_status_transition
  BEFORE UPDATE OF status ON bookings
  FOR EACH ROW EXECUTE FUNCTION validate_booking_status_transition();

CREATE FUNCTION apply_booking_capacity() RETURNS TRIGGER AS $$
DECLARE
  shipment_weight NUMERIC(12, 3);
  shipment_volume NUMERIC(12, 3);
  trip_record trips%ROWTYPE;
  is_becoming_capacity_consumer BOOLEAN;
  is_releasing_capacity BOOLEAN;
BEGIN
  is_becoming_capacity_consumer := TG_OP = 'UPDATE'
    AND OLD.status = 'REQUESTED'
    AND NEW.status = 'ACCEPTED';
  is_releasing_capacity := TG_OP = 'UPDATE'
    AND OLD.status IN ('ACCEPTED', 'PICKUP_CONFIRMED')
    AND NEW.status = 'CANCELLED';

  IF NOT is_becoming_capacity_consumer AND NOT is_releasing_capacity THEN
    RETURN NEW;
  END IF;

  SELECT weight_kg, volume_m3 INTO shipment_weight, shipment_volume
  FROM shipments WHERE id = NEW.shipment_id;
  SELECT * INTO trip_record FROM trips WHERE id = NEW.trip_id FOR UPDATE;

  IF is_becoming_capacity_consumer THEN
    IF trip_record.status NOT IN ('PUBLISHED', 'IN_PROGRESS') THEN
      RAISE EXCEPTION 'Trip % is not available for booking', NEW.trip_id USING ERRCODE = 'check_violation';
    END IF;
    IF trip_record.available_weight_kg < shipment_weight THEN
      RAISE EXCEPTION 'Insufficient trip weight capacity' USING ERRCODE = 'check_violation';
    END IF;
    IF shipment_volume IS NOT NULL AND trip_record.available_volume_m3 IS NOT NULL
       AND trip_record.available_volume_m3 < shipment_volume THEN
      RAISE EXCEPTION 'Insufficient trip volume capacity' USING ERRCODE = 'check_violation';
    END IF;

    UPDATE trips
    SET available_weight_kg = available_weight_kg - shipment_weight,
        available_volume_m3 = CASE
          WHEN shipment_volume IS NULL OR available_volume_m3 IS NULL THEN available_volume_m3
          ELSE available_volume_m3 - shipment_volume
        END,
        status = CASE WHEN available_weight_kg - shipment_weight = 0 THEN 'FULL'::trip_status ELSE status END
    WHERE id = NEW.trip_id;
    NEW.accepted_at = COALESCE(NEW.accepted_at, now());
  ELSIF is_releasing_capacity THEN
    UPDATE trips
    SET available_weight_kg = available_weight_kg + shipment_weight,
        available_volume_m3 = CASE
          WHEN shipment_volume IS NULL OR available_volume_m3 IS NULL THEN available_volume_m3
          ELSE available_volume_m3 + shipment_volume
        END,
        status = CASE WHEN status = 'FULL' THEN 'PUBLISHED'::trip_status ELSE status END
    WHERE id = NEW.trip_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_apply_capacity
  BEFORE UPDATE OF status ON bookings
  FOR EACH ROW EXECUTE FUNCTION apply_booking_capacity();

COMMIT;
