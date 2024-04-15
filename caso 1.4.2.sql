-- Caso 1
/*
- PROY_MOVILIZACION
- BIND: 
    Año de proceso extract(year from sysdate)
  , Comunas y Valor movilización adicional
    María Pinto $20.000
    Curacaví $25.000
    Talagante $30.000
    El Monte $35.000
    Buin $40.000
- % Moviliz normal es sueldo / 100.000
- execute immediate 'TRUNCATE TABLE PROY_MOVILIZACION';
*/
var b_anio number
exec :b_anio := extract(year from sysdate);
-- comunas con mov extra
var b_comuna_mp number
exec :b_comuna_mp := 117;
var b_comuna_cu number;
exec :b_comuna_cu := 118;
var b_comuna_ta number;
exec :b_comuna_ta := 119;
var b_comuna_em number;
exec :b_comuna_em := 120;
var b_comuna_bu number;
exec :b_comuna_bu := 121;
-- bonos de mov extra
var b_bono_mp number
exec :b_bono_mp := 20000;
var b_bono_cu number
exec :b_bono_cu := 25000;
var b_bono_ta number
exec :b_bono_ta := 30000;
var b_bono_em number
exec :b_bono_em := 35000;
var b_bono_bu number
exec :b_bono_bu := 40000;

DECLARE
v_min_id_emp number(3);
v_max_id_emp number(3);
v_id_emp empleado.id_emp%TYPE;
v_numrun_emp empleado.numrun_emp%TYPE;
v_dvrun_emp empleado.dvrun_emp%TYPE;
v_nombre_completo varchar2(100);
v_nombre_comuna comuna.nombre_comuna%TYPE;
v_id_comuna comuna.id_comuna%TYPE;
v_sueldo_base empleado.sueldo_base%TYPE;
v_porc_mov_normal number(3);
v_valor_mov_normal empleado.sueldo_base%TYPE;
v_valor_mov_extra empleado.sueldo_base%TYPE;
v_valor_total_mov  empleado.sueldo_base%TYPE;
BEGIN
    -- Limpiar tabla en tiempo de ejecución
    execute immediate 'TRUNCATE TABLE PROY_MOVILIZACION';
    
    -- saco el id menor y mayor de los empleados
    SELECT min(e.id_emp), max(e.id_emp)
    INTO v_min_id_emp, v_max_id_emp
    FROM empleado e;
    
    -- aca iteramos los empleados
    WHILE (v_min_id_emp <= v_max_id_emp) LOOP
        SELECT e.id_emp
             , numrun_emp
             , dvrun_emp
             , pnombre_emp||' '||snombre_emp||' '||appaterno_emp||' '||apmaterno_emp
             , c.nombre_comuna
             , c.id_comuna
             , e.sueldo_base
        INTO v_id_emp
           , v_numrun_emp
           , v_dvrun_emp
           , v_nombre_completo
           , v_nombre_comuna
           , v_id_comuna
           , v_sueldo_base
        FROM empleado e
        JOIN comuna c ON c.id_comuna = e.id_comuna
        WHERE e.id_emp = v_min_id_emp;
        
        v_porc_mov_normal := trunc(v_sueldo_base/100000);
        v_valor_mov_normal := round((v_porc_mov_normal * v_sueldo_base)/100);
        
        IF (v_id_comuna = :b_comuna_mp) THEN
            v_valor_mov_extra := :b_bono_mp;
        ELSIF (v_id_comuna = :b_comuna_cu) THEN
            v_valor_mov_extra := :b_bono_cu;
        ELSIF (v_id_comuna = :b_comuna_ta) THEN
            v_valor_mov_extra := :b_bono_ta;
        ELSIF (v_id_comuna = :b_comuna_em) THEN
            v_valor_mov_extra := :b_bono_em;
        ELSIF (v_id_comuna = :b_comuna_bu) THEN
            v_valor_mov_extra := :b_bono_bu;
        ELSE
            v_valor_mov_extra := 0;
        END IF;
        
        -- insertar datos a tabla de trabajo
        INSERT INTO PROY_MOVILIZACION 
        VALUES (
             :b_anio
           , v_id_emp
           , v_numrun_emp
           , v_dvrun_emp
           , v_nombre_completo
           , v_nombre_comuna
           , v_sueldo_base
           , v_porc_mov_normal
           , v_valor_mov_normal
           , v_valor_mov_extra
           , v_valor_mov_normal + v_valor_mov_extra
        );
        
        v_min_id_emp := v_min_id_emp + 10;
    END LOOP;
    
    COMMIT;
END;

-- Caso 3
/*
- almacenar HIST_ARRIENDO_ANUAL_CAMION.
- ANNO_PROCESO (año de ejecución) de forma paramétrica.
- procesar ciclo (loop) TODOS los camiones.
- todos los arriendos efectuaron AÑO ANTERIOR (ANNO_PROCESO - 1).
- rebajar (update camion) valor arriendo por día y la garantía por día en un 22,5% si el camión se arrendó menos de cuatro veces en el año.
- el porcentaje de rebaja (22.5%) paramétrico.
*/
-- declaración de variables bind
VAR b_anno_proceso number
VAR b_porc_rebaja number
-- asignación de valores paramétricos
EXEC :b_anno_proceso := extract(year from sysdate);
EXEC :b_porc_rebaja := 22.5;
DECLARE
    -- declaracion de variables locales
    v_min_id_camion number(4);
    v_max_id_camion number(4);
    v_total_arriendos number(2);
    -- variables para el insert
    V_ID_CAMION camion.id_camion%TYPE;
    V_NRO_PATENTE camion.nro_patente%TYPE;
    V_VALOR_ARRIENDO_DIA camion.valor_arriendo_dia%TYPE;
    V_VALOR_GARANTIA_DIA camion.valor_garantia_dia%TYPE;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE HIST_ARRIENDO_ANUAL_CAMION';
        
    SELECT min(c.id_camion), max(c.id_camion)
    INTO v_min_id_camion, v_max_id_camion
    FROM camion c;
    
    FOR i IN v_min_id_camion .. v_max_id_camion LOOP
    
        SELECT count(*)
        INTO v_total_arriendos
        FROM arriendo_camion ac
        WHERE ac.id_camion = i -- id camión
        AND extract(year from ac.fecha_ini_arriendo) = :b_anno_proceso - 1;
        
        -- extraemo variables para el insert
        SELECT ID_CAMION
             , NRO_PATENTE
             , VALOR_ARRIENDO_DIA
             , VALOR_GARANTIA_DIA
        INTO V_ID_CAMION
             , V_NRO_PATENTE
             , V_VALOR_ARRIENDO_DIA
             , V_VALOR_GARANTIA_DIA
        FROM camion c
        WHERE c.id_camion = i;
        
        -- insertar a tabla HIST_ARRIENDO_ANUAL_CAMION
        INSERT INTO HIST_ARRIENDO_ANUAL_CAMION
        values (
            :b_anno_proceso
          , V_ID_CAMION
          , V_NRO_PATENTE
          , V_VALOR_ARRIENDO_DIA
          , V_VALOR_GARANTIA_DIA
          , v_total_arriendos
        );
        /*
        -- insertar a tabla HIST_ARRIENDO_ANUAL_CAMION
        INSERT INTO HIST_ARRIENDO_ANUAL_CAMION
        SELECT :b_anno_proceso
             , ID_CAMION
             , NRO_PATENTE
             , VALOR_ARRIENDO_DIA
             , VALOR_GARANTIA_DIA
             , v_total_arriendos
        FROM camion c
        WHERE c.id_camion = i;
        */
        
        IF (v_total_arriendos < 4) THEN
            UPDATE CAMION c
            SET c.valor_arriendo_dia = c.valor_arriendo_dia - round((c.valor_arriendo_dia * :b_porc_rebaja)/100)
              , c.valor_garantia_dia = c.valor_garantia_dia - round((c.valor_garantia_dia * :b_porc_rebaja)/100)
            WHERE c.id_camion = i;
        END IF;
        
    END LOOP;
    
    COMMIT;
END;

-- Caso 4
/*
- 30% ganancias se distribuyen
  Tramos Sueldo Base, Porcentaje Bonificación
  n forma paramétrica
  $ 320.000 $ 600,000  35% 
  $ 600.001 $1.300.000 25%
  $1.300.001 $1.800.000 20%
  $1.800.001 $2.200.000 15%
  $2.200.001 Y MAS 5%
- paramétrico (BIND globales), ganancias del año $200.000.000
- paramétrico (BIND) porcentaje utilidad a distribuir 30%
- Monto bonificación calcular sentencias PL/SQL, NO SELECT DEBERÁ, usar Estructura de Control Condicional.
- resultado almacenado en BONIF_POR_UTILIDAD
- ANNO_PROCESO  año actual hay que pasarlo paramétrica.
- procesar TODOS los empleados (recorrer la tabla con loop).
- TRUNCAR la tabla BONIF_POR_UTILIDAD en tiempo de ejecución
- DEBERAN documentar todas las sentencias SQL.
*/

-- declaración variable BIND
var b_anno_proceso number;
var b_ganancias number;
var b_porcent_utilidad number;
-- variables bind rangos de bonificación
var b_rango1_min number;
var b_rango1_max number;
var b_rango1_bono number;
var b_rango2_min number;
var b_rango2_max number;
var b_rango2_bono number;
var b_rango3_min number;
var b_rango3_max number;
var b_rango3_bono number;
var b_rango4_min number;
var b_rango4_max number;
var b_rango4_bono number;
var b_rango5_min number;
var b_rango5_max number;
var b_rango5_bono number;
-- inicializando a variables BIND
exec :b_anno_proceso := extract(year from sysdate);
exec :b_ganancias := 200000000;
exec :b_porcent_utilidad := 30;
exec :b_rango1_min := 320000;
exec :b_rango1_max := 600000;
exec :b_rango1_bono := 35;
exec :b_rango2_min := 600001;
exec :b_rango2_max := 1300000;
exec :b_rango2_bono := 25;
exec :b_rango3_min := 1300001;
exec :b_rango3_max := 1800000;
exec :b_rango3_bono := 20;
exec :b_rango4_min := 1800001;
exec :b_rango4_max := 2200000;
exec :b_rango4_bono := 15;
exec :b_rango5_min := 2200001;
exec :b_rango5_bono := 5;

DECLARE
    v_min_id_emp number(3);
    v_max_id_emp number(3);
    v_sueldo_base empleado.sueldo_base%TYPE;
    v_rango1_total number(3);
    v_rango2_total number(3);
    v_rango3_total number(3);
    v_rango4_total number(3);
    v_rango5_total number(3);
    v_valor_bonif number(12);
    v_factor_utilidad number(12);
BEGIN
    -- TRUNCAR tabla en tiempo de ejecución.
    EXECUTE IMMEDIATE 'TRUNCATE TABLE BONIF_POR_UTILIDAD';
    
    -- 60M a repartir
    v_factor_utilidad := round((:b_ganancias * :b_porcent_utilidad)/100);
    
    -- sacar totales por tramo
    SELECT count(*)
    INTO v_rango1_total
    FROM empleado
    WHERE sueldo_base between :b_rango1_min and :b_rango1_max;
    
    SELECT count(*)
    INTO v_rango2_total
    FROM empleado
    WHERE sueldo_base between :b_rango2_min and :b_rango2_max;
    
    SELECT count(*)
    INTO v_rango3_total
    FROM empleado
    WHERE sueldo_base between :b_rango3_min and :b_rango3_max;
    
    SELECT count(*)
    INTO v_rango4_total
    FROM empleado
    WHERE sueldo_base between :b_rango4_min and :b_rango4_max;
    
    SELECT count(*)
    INTO v_rango5_total
    FROM empleado
    WHERE sueldo_base >= :b_rango5_min;
    
    -- sacar min y max de tabla empleado
    SELECT min(id_emp), max(id_emp)
    INTO v_min_id_emp, v_max_id_emp
    FROM empleado;
    
    LOOP
        -- tengo que sacar el salario de cada empleado
        SELECT sueldo_base
        INTO v_sueldo_base
        FROM empleado
        WHERE id_emp = v_min_id_emp;
        
        v_valor_bonif := 
        CASE 
            WHEN v_sueldo_base BETWEEN :b_rango1_min and :b_rango1_max then round(((:b_rango1_bono * v_factor_utilidad)/100)/v_rango1_total)
            WHEN v_sueldo_base BETWEEN :b_rango2_min and :b_rango2_max then round(((:b_rango2_bono * v_factor_utilidad)/100)/v_rango2_total)
            WHEN v_sueldo_base BETWEEN :b_rango3_min and :b_rango3_max then round(((:b_rango3_bono * v_factor_utilidad)/100)/v_rango3_total)
            WHEN v_sueldo_base BETWEEN :b_rango4_min and :b_rango4_max then round(((:b_rango4_bono * v_factor_utilidad)/100)/v_rango4_total)
            WHEN v_sueldo_base >= :b_rango5_min then round(((:b_rango5_bono * v_factor_utilidad)/100)/v_rango5_total)
            ELSE 0
        END;
        
        INSERT INTO BONIF_POR_UTILIDAD
        values (
            :b_anno_proceso
           ,v_min_id_emp
           ,v_sueldo_base
           ,v_valor_bonif
        );
        -- dbms_output.put_line('El sueldo base es: '||v_sueldo_base);
        
        v_min_id_emp := v_min_id_emp + 10;
        EXIT WHEN (v_min_id_emp > v_max_id_emp);
    END LOOP;
    
    COMMIT;-- Guarda los cambios a la BD ¡IMPORTANTISIMO!.
END;