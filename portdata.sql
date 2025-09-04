create database Datadashboard;
use Datadashboard;

ALTER TABLE vessels
ADD CONSTRAINT FK_vessels_berths
FOREIGN KEY (BERTH_ID) REFERENCES berths(BERTH_ID);

 ALTER TABLE vessels
ADD CONSTRAINT FK_vessels_ports
FOREIGN KEY (PORT_ID) REFERENCES ports(PORT_ID);

ALTER TABLE berths
ADD CONSTRAINT FK_berths_ports
FOREIGN KEY (PORT_ID) REFERENCES ports(PORT_ID);

ALTER TABLE portcalls
ADD CONSTRAINT FK_portcalls_berths
FOREIGN KEY (BERTH_ID) REFERENCES berths(BERTH_ID);

 ALTER TABLE portcalls
ADD CONSTRAINT FK_portcalls_vessels
FOREIGN KEY (VESSEL_NO) REFERENCES vessels(VESSEL_NO);

ALTER TABLE portcalls
ADD CONSTRAINT FK_portcalls_ports
FOREIGN KEY (PORT_ID) REFERENCES ports(PORT_ID);

--------berth utilization
SELECT Berths.BERTHING_BERTH_CODE,
  COUNT(Berths.VESSEL_NO) AS Total_Vessels_Berthed,
  MIN(Berths.BERTHING_DATE) AS First_Berthing,
   MAX(Berths.BERTHING_DATE) AS Last_Berthing
FROM Berths
GROUP BY Berths.BERTHING_BERTH_CODE
ORDER BY Total_Vessels_Berthed DESC;

-----------------average turnaround time of the vessels
SELECT Vessels.VESSEL_NAME,
AVG(DATEDIFF(HOUR, Vessels.BERTHING_DATE, Vessels.SAILED_DT)) AS Average_Turnaround_Hours
FROM Vessels
WHERE Vessels.SAILED_DT IS NOT NULL
GROUP BY Vessels.VESSEL_NAME
ORDER BY Average_Turnaround_Hours DESC;

------------active vessels
SELECT 
    Vessels.VESSEL_NO,
    Vessels.VESSEL_NAME,
    Vessels.BERTHING_DATE,
    Vessels.BERTHING_BERTH_CODE
FROM Vessels
WHERE Vessels.BERTHING_DATE IS NOT NULL
  AND Vessels.SAILED_DT IS NULL
ORDER BY Vessels.BERTHING_DATE;

------stored procedure to assign vessel to berth with availability check

CREATE PROCEDURE Assign_Vessel_To_Berth
    @Vessel_No INT,
    @Berth_Code NVARCHAR(50),
    @Berthing_Date DATETIME
AS
BEGIN
    IF EXISTS (
        SELECT 1
 FROM Berths
  WHERE Berths.BERTHING_BERTH_CODE = @Berth_Code
     AND Berths.BERTHING_DATE = @Berthing_Date
    )
    BEGIN
        PRINT 'Berth is already occupied at the given time.';
  END
 ELSE
  BEGIN
  INSERT INTO Berths (VESSEL_NO, VESSEL_NAME, BERTHING_BERTH_CODE, BERTHING_DATE)
 SELECT Vessels.VESSEL_NO, Vessels.VESSEL_NAME, @Berth_Code, @Berthing_Date
   FROM Vessels
  WHERE Vessels.VESSEL_NO = @Vessel_No;
 PRINT 'Vessel successfully assigned to berth.';
    END
END;

----trigger to auto-update berth status when vessel departs

CREATE TRIGGER Update_Berth_Status_On_Departure
ON Vessels
AFTER UPDATE
AS
BEGIN
    IF UPDATE(SAILED_DT)
    BEGIN
 UPDATE Berths
  SET PRIORITY = 'AVAILABLE'
 FROM Berths
  INNER JOIN Vessels
  ON Berths.VESSEL_NO = Vessels.VESSEL_NO
  WHERE Vessels.SAILED_DT IS NOT NULL;
  END
END;

--------to view vessel schedules

SELECT 
Vessels.VESSEL_NO,
  Vessels.VESSEL_NAME,
  Vessels.ANCHORAGE_DT,
  Vessels.BERTHING_DATE,
  Vessels.BERTHING_BERTH_CODE,
 Vessels.SAILED_DT
FROM Vessels
ORDER BY Vessels.BERTHING_DATE;

------to view cargo volume
SELECT 
 Vessels.BERTHING_BERTH_CODE,
  SUM(Vessels.CARGO_TONNAGE) AS Total_Cargo_Tonnage
FROM Vessels
GROUP BY Vessels.BERTHING_BERTH_CODE
ORDER BY Total_Cargo_Tonnage DESC;
