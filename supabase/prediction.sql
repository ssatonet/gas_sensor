-- Function to predict sensor life based on linear regression
-- Returns:
--   predicted_date: Date when sensitivity is expected to hit threshold
--   slope: Rate of degradation per day
--   r_squared: Quality of fit (optional, simplified here)

CREATE OR REPLACE FUNCTION predict_sensor_life(
    target_equipment_id UUID,
    threshold FLOAT DEFAULT 60.0
)
RETURNS TABLE (
    predicted_date DATE,
    slope FLOAT,
    intercept FLOAT,
    days_remaining INT
) AS $$
DECLARE
    n INT;
    sum_x FLOAT := 0;
    sum_y FLOAT := 0;
    sum_xy FLOAT := 0;
    sum_xx FLOAT := 0;
    b FLOAT; -- slope
    a FLOAT; -- intercept
    latest_replacement_date DATE;
    start_date DATE;
    x_prime FLOAT; -- Days until threshold from start_date
    pred_date DATE;
BEGIN
    -- 1. Find the last sensor replacement date or a reset point (sensitivity >= 95%)
    -- We look for the latest inspection where is_sensor_replaced is true OR sensitivity is high
    SELECT MAX(inspection_date) INTO latest_replacement_date
    FROM inspections
    WHERE equipment_id = target_equipment_id
      AND (is_sensor_replaced = TRUE OR gas_sensitivity >= 95.0);

    -- If no replacement found, use the very first inspection
    IF latest_replacement_date IS NULL THEN
        SELECT MIN(inspection_date) INTO latest_replacement_date
        FROM inspections
        WHERE equipment_id = target_equipment_id;
    END IF;
    
    start_date := latest_replacement_date;

    -- 2. Collect data points (x = days since start_date, y = sensitivity)
    -- We use a CTE to calculate sums for linear regression
    WITH data_points AS (
        SELECT
            (inspection_date - start_date)::FLOAT as x,
            gas_sensitivity as y
        FROM inspections
        WHERE equipment_id = target_equipment_id
          AND inspection_date >= start_date
          AND gas_sensitivity IS NOT NULL
    ),
    stats AS (
        SELECT
            COUNT(*) as count_n,
            SUM(x) as s_x,
            SUM(y) as s_y,
            SUM(x*y) as s_xy,
            SUM(x*x) as s_xx
        FROM data_points
    )
    SELECT count_n, s_x, s_y, s_xy, s_xx INTO n, sum_x, sum_y, sum_xy, sum_xx FROM stats;

    -- Need at least 2 points to predict
    IF n < 2 OR (n * sum_xx - sum_x * sum_x) = 0 THEN
        RETURN QUERY SELECT NULL::DATE, NULL::FLOAT, NULL::FLOAT, NULL::INT;
        RETURN;
    END IF;

    -- 3. Calculate Slope (b) and Intercept (a)
    -- b = (n*sum_xy - sum_x*sum_y) / (n*sum_xx - sum_x^2)
    -- a = (sum_y - b*sum_x) / n
    b := (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);
    a := (sum_y - b * sum_x) / n;

    -- 4. Calculate predicted date
    -- Target Y = threshold
    -- threshold = a + b * x_prime
    -- x_prime = (threshold - a) / b
    
    IF b >= 0 THEN
        -- Slope is positive or zero (not degrading), cannot predict failure
        RETURN QUERY SELECT NULL::DATE, b, a, NULL::INT;
    ELSE
        x_prime := (threshold - a) / b;
        pred_date := (start_date + (x_prime || ' days')::INTERVAL)::DATE;
        
        -- Return results
        -- days_remaining should be from NOW, not from start_date
        RETURN QUERY SELECT 
            pred_date,
            b,
            a,
            (pred_date - CURRENT_DATE)::INT;
    END IF;
END;
$$ LANGUAGE plpgsql;
