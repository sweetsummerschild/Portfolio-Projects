-- Change sales_date data type
ALTER TABLE
    housing..nashville_housing
ALTER COLUMN
    sales_date DATE;

-- property_address NULLs
SELECT
    parcel_id,
    property_address
FROM
    housing..nashville_housing
WHERE
    property_address IS NULL;

---- Duplicate parcel_id has the same matching property_address
SELECT
    parcel_id,
    property_address,
    COUNT(unique_id) OVER (PARTITION BY parcel_id) AS unique_id_count
FROM
    housing..nashville_housing
ORDER BY
    3 DESC,
    1;

---- Fill property_address NULLs
SELECT
    a.parcel_id,
    a.property_address,
    b.parcel_id,
    b.property_address,
    ISNULL(a.property_address, b.property_address) AS property_address
FROM
    housing..nashville_housing a
    JOIN housing..nashville_housing b ON a.parcel_id = b.parcel_id
        AND a.unique_id != b.unique_id
WHERE
    a.property_address IS NULL
ORDER BY
    1;

UPDATE
    a
SET
    property_address = ISNULL(a.property_address, b.property_address)
FROM
    housing..nashville_housing a
    JOIN housing..nashville_housing b ON a.parcel_id = b.parcel_id
        AND a.unique_id != b.unique_id
WHERE
    a.property_address IS NULL;

-- Breaking down property_address
SELECT
    property_address,
    SUBSTRING(
        property_address,
        1,
        CHARINDEX(',', property_address) - 1
    ) AS property_add,
    SUBSTRING(
        property_address,
        CHARINDEX(',', property_address) + 1,
        LEN(property_address)
    ) AS property_city
FROM
    housing..nashville_housing;

ALTER TABLE
    housing..nashville_housing
ADD
    property_add NVARCHAR (250),
    property_city NVARCHAR (250);

UPDATE
    housing..nashville_housing
SET
    property_add = SUBSTRING(
        property_address,
        1,
        CHARINDEX(',', property_address) - 1
    ),
    property_city = SUBSTRING(
        property_address,
        CHARINDEX(',', property_address) + 1,
        LEN(property_address)
    );

-- Breaking down owner_address
SELECT
    owner_address,
    PARSENAME(REPLACE(owner_address, ',', '.'), 3),
    PARSENAME(REPLACE(owner_address, ',', '.'), 2),
    PARSENAME(REPLACE(owner_address, ',', '.'), 1)
FROM
    housing..nashville_housing
ORDER BY
    1 DESC;

ALTER TABLE
    housing..nashville_housing
ADD
    owner_add NVARCHAR (250),
    owner_city NVARCHAR (250),
    owner_state NVARCHAR (250);

UPDATE
    housing..nashville_housing
SET
    owner_add = PARSENAME(REPLACE(owner_address, ',', '.'), 3),
    owner_city = PARSENAME(REPLACE(owner_address, ',', '.'), 2),
    owner_state = PARSENAME(REPLACE(owner_address, ',', '.'), 1);

-- Dropping excess columns
ALTER TABLE
    housing..nashville_housing DROP COLUMN property_address,
    owner_address;

-- Replacing mismatched values in sold_as_vacant
SELECT
    DISTINCT sold_as_vacant,
    COUNT(sold_as_vacant)
FROM
    housing..nashville_housing
GROUP BY
    sold_as_vacant
ORDER BY
    2;

SELECT
    sold_as_vacant,
    CASE
        WHEN sold_as_vacant = 'Y' THEN 'Yes'
        WHEN sold_as_vacant = 'N' THEN 'No'
        ELSE sold_as_vacant
    END
FROM
    housing..nashville_housing;

UPDATE
    housing..nashville_housing
SET
    sold_as_vacant = CASE
        WHEN sold_as_vacant = 'Y' THEN 'Yes'
        WHEN sold_as_vacant = 'N' THEN 'No'
        ELSE sold_as_vacant
    END;

-- Removing duplicate entries
WITH
    dup_cte
    AS
    (
        SELECT
            RANK() OVER (
            PARTITION BY parcel_id,
            property_add,
            legal_reference,
            sales_date,
            sales_price
            ORDER BY
                unique_id
        ) AS dup_count,
            *
        FROM
            housing..nashville_housing
    )
DELETE FROM
    dup_cte
WHERE
    dup_count > 1;

