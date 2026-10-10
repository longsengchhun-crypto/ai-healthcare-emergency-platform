-- Display data for bilingual (Khmer / Latin) directory entries and profile images.
ALTER TABLE doctor_profiles ADD COLUMN name_latin VARCHAR(150);
ALTER TABLE doctor_profiles ADD COLUMN specialty_km VARCHAR(120);
ALTER TABLE doctor_profiles ADD COLUMN bio_en VARCHAR(1000);
ALTER TABLE doctor_profiles ADD COLUMN photo_url VARCHAR(255);
ALTER TABLE doctor_profiles ADD COLUMN years_experience INT;
ALTER TABLE doctor_profiles ADD COLUMN languages VARCHAR(120);

ALTER TABLE hospitals ADD COLUMN name_latin VARCHAR(200);
ALTER TABLE hospitals ADD COLUMN photo_url VARCHAR(255);
ALTER TABLE hospitals ADD COLUMN opening_hours VARCHAR(120);
