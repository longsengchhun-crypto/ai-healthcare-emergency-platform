-- Reference data: roles, permissions and their mapping. Contains no accounts or credentials.
INSERT INTO roles (id, name, description) VALUES
 ('00000000-0000-4000-8000-000000000001', 'PATIENT',        'Patient using the mobile app'),
 ('00000000-0000-4000-8000-000000000002', 'DOCTOR',         'Clinician managing own schedule and authorised patients'),
 ('00000000-0000-4000-8000-000000000003', 'HOSPITAL_STAFF', 'Hospital operator coordinating emergency response'),
 ('00000000-0000-4000-8000-000000000004', 'SYSTEM_ADMIN',   'Platform administrator');

INSERT INTO permissions (id, code, description) VALUES
 ('00000000-0000-4000-9000-000000000001', 'PROFILE_OWN',            'Manage own patient profile and contacts'),
 ('00000000-0000-4000-9000-000000000002', 'APPOINTMENT_BOOK',       'Book, reschedule and cancel own appointments'),
 ('00000000-0000-4000-9000-000000000003', 'APPOINTMENT_DOCTOR',     'Manage appointments assigned to self'),
 ('00000000-0000-4000-9000-000000000004', 'APPOINTMENT_ADMIN',      'View and manage all appointments'),
 ('00000000-0000-4000-9000-000000000005', 'RECORD_VIEW_OWN',        'View own medical records'),
 ('00000000-0000-4000-9000-000000000006', 'RECORD_WRITE_CLINICAL',  'Author clinician medical records for authorised patients'),
 ('00000000-0000-4000-9000-000000000007', 'EMERGENCY_CREATE',       'Create an emergency event for self'),
 ('00000000-0000-4000-9000-000000000008', 'EMERGENCY_QUEUE_VIEW',   'View the emergency response queue'),
 ('00000000-0000-4000-9000-000000000009', 'EMERGENCY_MANAGE',       'Acknowledge, assign and update emergency events'),
 ('00000000-0000-4000-9000-000000000010', 'AI_USE',                 'Use AI assistance features'),
 ('00000000-0000-4000-9000-000000000011', 'USER_ADMIN',             'Manage users and roles'),
 ('00000000-0000-4000-9000-000000000012', 'AUDIT_VIEW',             'View audit logs'),
 ('00000000-0000-4000-9000-000000000013', 'DOCTOR_VERIFY',          'Change doctor verification status'),
 ('00000000-0000-4000-9000-000000000014', 'DIRECTORY_MANAGE',       'Manage hospitals and departments'),
 ('00000000-0000-4000-9000-000000000015', 'SETTINGS_MANAGE',        'Manage system settings');

-- PATIENT
INSERT INTO role_permissions (role_id, permission_id)
SELECT '00000000-0000-4000-8000-000000000001', id FROM permissions
 WHERE code IN ('PROFILE_OWN', 'APPOINTMENT_BOOK', 'RECORD_VIEW_OWN', 'EMERGENCY_CREATE', 'AI_USE');
-- DOCTOR
INSERT INTO role_permissions (role_id, permission_id)
SELECT '00000000-0000-4000-8000-000000000002', id FROM permissions
 WHERE code IN ('APPOINTMENT_DOCTOR', 'RECORD_WRITE_CLINICAL', 'EMERGENCY_QUEUE_VIEW', 'AI_USE');
-- HOSPITAL_STAFF (deliberately has no record-viewing permission)
INSERT INTO role_permissions (role_id, permission_id)
SELECT '00000000-0000-4000-8000-000000000003', id FROM permissions
 WHERE code IN ('EMERGENCY_QUEUE_VIEW', 'EMERGENCY_MANAGE', 'APPOINTMENT_ADMIN', 'DIRECTORY_MANAGE', 'AUDIT_VIEW');
-- SYSTEM_ADMIN
INSERT INTO role_permissions (role_id, permission_id)
SELECT '00000000-0000-4000-8000-000000000004', id FROM permissions
 WHERE code IN ('USER_ADMIN', 'AUDIT_VIEW', 'DOCTOR_VERIFY', 'DIRECTORY_MANAGE', 'SETTINGS_MANAGE',
                'EMERGENCY_QUEUE_VIEW', 'APPOINTMENT_ADMIN');

INSERT INTO system_settings (setting_key, setting_value, updated_at) VALUES
 ('emergency.local_number', 'UNCONFIGURED', CURRENT_TIMESTAMP),
 ('emergency.disclaimer', 'This is an in-app demonstration response workflow, not a real emergency dispatch network.', CURRENT_TIMESTAMP);
