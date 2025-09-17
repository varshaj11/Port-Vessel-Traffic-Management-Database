CREATE DATABASE Datadashboard;
USE Datadashboard;

-- Foreign Keys
ALTER TABLE Vessels
ADD CONSTRAINT FK_vessels_ports
FOREIGN KEY (PORT_ID) REFERENCES Ports(PORT_ID);

ALTER TABLE Berths
ADD CONSTRAINT FK_berths_ports
FOREIGN KEY (PORT_ID) REFERENCES Ports(PORT_ID);

ALTER TABLE Portcalls
ADD CONSTRAINT FK_portcalls_ports
FOREIGN KEY (PORT_ID) REFERENCES Ports(PORT_ID);

ALTER TABLE Portcalls
ADD CONSTRAINT FK_portcalls_berths
FOREIGN KEY (BERTH_ID) REFERENCES Berths(BERTH_ID);

ALTER TABLE Portcalls
ADD CONSTRAINT FK_portcalls_vessels
FOREIGN KEY (VESSEL_NO) REFERENCES Vessels(VESSEL_NO);


-- 1. berth utilization

SELECT 
Berths.BERTHING_BERTH_CODE,
  COUNT(Portcalls.VESSEL_NO) AS Total_Vessels_Berthed,
  MIN(Portcalls.BERTHING_DATE) AS First_Berthing,
 MAX(Portcalls.BERTHING_DATE) AS Last_Berthing
FROM Berths
LEFT JOIN Portcalls ON Berths.BERTH_ID = Portcalls.BERTH_ID
GROUP BY Berths.BERTHING_BERTH_CODE
ORDER BY Total_Vessels_Berthed DESC;


-- 2. average turnaround time 

SELECT 
Vessels.VESSEL_NAME,
  AVG(DATEDIFF(HOUR, Portcalls.BERTHING_DATE, Portcalls.SAILED_DT)) AS Average_Turnaround_Hours
FROM Vessels
INNER JOIN Portcalls ON Vessels.VESSEL_NO = Portcalls.VESSEL_NO
WHERE Portcalls.SAILED_DT IS NOT NULL
GROUP BY Vessels.VESSEL_NAME
ORDER BY Average_Turnaround_Hours DESC;


-- 3. active vessels (berthed but not yet sailed)

SELECT 
    Vessels.VESSEL_NO,
    Vessels.VESSEL_NAME,
    Portcalls.BERTHING_DATE,
    Portcalls.BERTHING_BERTH_CODE
FROM Vessels
INNER JOIN Portcalls ON Vessels.VESSEL_NO = Portcalls.VESSEL_NO
WHERE Portcalls.BERTHING_DATE IS NOT NULL
  AND Portcalls.SAILED_DT IS NULL
ORDER BY Portcalls.BERTHING_DATE;


-- 4. stored procedure: assign vessel to berth

CREATE PROCEDURE Assign_Vessel_To_Berth
    @Vessel_No NVARCHAR(50),
    @Berth_Code NVARCHAR(50),
    @Berthing_Date DATETIME
AS
BEGIN
  IF EXISTS (
  SELECT 1
   FROM Portcalls
    INNER JOIN Berths ON Portcalls.BERTH_ID = Berths.BERTH_ID
   WHERE Berths.BERTHING_BERTH_CODE = @Berth_Code
  AND Portcalls.BERTHING_DATE = @Berthing_Date
    )
    BEGIN
        PRINT 'Berth is already occupied at the given time.';
    END
    ELSE
    BEGIN
  INSERT INTO Portcalls (PORT_ID, BERTH_ID, VESSEL_NO, VESSEL_NAME, BERTHING_BERTH_CODE, BERTHING_DATE)
   SELECT Vessels.PORT_ID, Berths.BERTH_ID, Vessels.VESSEL_NO, Vessels.VESSEL_NAME, @Berth_Code, @Berthing_Date
   FROM Vessels
   INNER JOIN Berths ON Vessels.PORT_ID = Berths.PORT_ID
   WHERE Vessels.VESSEL_NO = @Vessel_No;
  PRINT 'Vessel successfully assigned to berth.';
    END
END;


-- 5. trigger: auto-update berth status when vessel departs

CREATE TRIGGER Update_Berth_Status_On_Departure
ON Portcalls
AFTER UPDATE
AS
BEGIN
    IF UPDATE(SAILED_DT)
    BEGIN
 UPDATE Portcalls
  SET PRIORITY = 'AVAILABLE'
  WHERE Portcalls.SAILED_DT IS NOT NULL;
    END
END;


-- 6. view vessel schedules

SELECT 
  Vessels.VESSEL_NO,
    Vessels.VESSEL_NAME,
 Portcalls.ANCHORAGE_DT,
  Portcalls.BERTHING_DATE,
   Portcalls.BERTHING_BERTH_CODE,
  Portcalls.SAILED_DT
FROM Vessels
INNER JOIN Portcalls ON Vessels.VESSEL_NO = Portcalls.VESSEL_NO
ORDER BY Portcalls.BERTHING_DATE;


-- 7. view cargo volume

SELECT 
  Portcalls.BERTHING_BERTH_CODE,
  SUM(Portcalls.CARGO_TONNAGE) AS Total_Cargo_Tonnage
FROM Portcalls
GROUP BY Portcalls.BERTHING_BERTH_CODE
ORDER BY Total_Cargo_Tonnage DESC;
