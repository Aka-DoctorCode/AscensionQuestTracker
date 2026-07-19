🧬 Árbol Genealógico de APIs: WoW Objective Tracker (Patch 12.0.5+)

Este documento detalla la jerarquía y el desglose técnico de las APIs del cliente de World of Warcraft involucradas en la recopilación de datos, interactividad y renderizado de misiones, gestas, logros y contenido rastreable.

🗺️ Mapa Jerárquico General

[WoW Client Engine (API 12.0.5+)]
 ├── [1. Marco Visual Core] ── ObjectiveTrackerFrame (FrameXML Global)
 ├── [2. Registro de Misiones] ── C_QuestLog & C_CampaignInfo
 ├── [3. Contenido Dinámico] ── C_TaskQuest & C_BountyInfo
 ├── [4. Instancias y Desafíos] ── C_Scenario & C_ChallengeMode
 ├── [5. Sistema Unificado de Rastreo] ── C_ContentTracking
 ├── [6. Economías y Recompensas] ── C_TradeSkillUI & C_PerksActivities
 ├── [7. Gestor de Widgets Dinámicos] ── C_UIWidgetManager
 └── [8. Navegación Espacial] ── C_SuperTrack


📦 Desglose Detallado por Familias (Ancestros, Métodos y Eventos)

1. Marco Visual Core & Controladores de Taint (El Ancestro Físico)

Representa el contenedor gráfico nativo que debemos ocultar o "secuestrar" y los métodos para manipular los marcos de forma segura sin provocar bloqueos por ejecución protegida (lockdown) en combate.

Marcos Globales:

ObjectiveTrackerFrame: Contenedor principal de la interfaz nativa.

Métodos Macro:

ObjectiveTrackerFrame:UnregisterAllEvents(): Corta la comunicación del tracker nativo con el motor del juego.

ObjectiveTrackerFrame:Hide(): Oculta la representación visual nativa.

InCombatLockdown(): Retorna un booleano. El tracker personalizado debe comprobar esto antes de realizar mutaciones de geometría o visibilidad de frames protegidos.

Seguridad de Ejecución (Zero Taint):

SecureActionButtonTemplate (Plantilla XML): Plantilla obligatoria para botones interactivos que lanzan hechizos o usan ítems de misión en combate.

RegisterStateDriver(frame, state, conditional): Permite derivar la visibilidad de elementos protegidos al entorno de macros seguro de Blizzard.

2. Registro de Misiones y Campañas (C_QuestLog & C_CampaignInfo)

Maneja las misiones tradicionales estructuradas, las misiones de campaña de la historia principal y el diario de misiones del jugador.

C_QuestLog
 ├── GetNumQuestWatches() ──> numWatches (number)
 ├── GetQuestIDForQuestWatchIndex(index) ──> questID (number)
 ├── GetInfo(questID) ──> questInfo (table)
 │    ├── title (string)
 │    ├── level (number)
 │    ├── campaignID (number)
 │    └── isHeader (boolean)
 └── GetQuestObjectives(questID) ──> objectives (table)
      └── [Objective Node]
           ├── text (string)
           ├── type (string)
           ├── finished (boolean)
           ├── numFulfilled (number)
           └── numRequired (number)


Métodos Complementarios:

C_CampaignInfo.GetCampaignInfo(campaignID): Retorna metadatos de la campaña (progreso del capítulo, nombre de la facción).

Eventos Críticos de Sincronización:

QUEST_LOG_UPDATE: Disparado ante cualquier cambio de progreso o estado en el diario de misiones.

QUEST_WATCH_LIST_CHANGED: Disparado cuando el jugador pinea o despinea manualmente una misión de su tracker.

3. Contenido Dinámico por Proximidad (C_TaskQuest & C_BountyInfo)

Maneja las Misiones del Mundo (World Quests) y los Objetivos de Bonificación que se activan automáticamente cuando el jugador entra en su rango geográfico de influencia.

C_TaskQuest
 ├── GetQuestsForPlayerByMapID(uiMapID) ──> taskQuests (table)
 │    └── [Task Node]
 │         ├── questId (number)
 │         └── inProgress (boolean)
 ├── GetQuestInfoByQuestID(questID) ──> title (string), factionID (number)
 └── GetQuestTimeLeftMinutes(questID) ──> minutesLeft (number)


Sistemas de Recompensas de Zona:

C_BountyInfo.GetBountiesForMapID(uiMapID): Retorna el progreso de emisarios o convocatorias activas en el mapa seleccionado.

Eventos Críticos:

QUEST_ACCEPTED / QUEST_REMOVED: Se disparan al entrar y salir físicamente del área de una misión del mundo.

4. Instancias, Profundidades y Cronómetros (C_Scenario & C_ChallengeMode)

Namespace asíncrono que gobierna las gestas (Scenarios), las Profundidades (Delves) y las mazmorras Mythic+ con sus afijos y penalizaciones de tiempo.

C_Scenario
 ├── IsInScenario() ──> active (boolean)
 ├── GetInfo() ──> name (string), currentStage (number), numStages (number), flags (number)
 └── GetStepInfo() ──> stageName (string), stageDescription (string), numCriteria (number)
      └── [Criteria Node via GetCriteriaInfo(criteriaIndex)]
           ├── description (string)
           ├── completed (boolean)
           ├── quantity (number)
           └── totalQuantity (number)


Motor de Mythic+ (C_ChallengeMode):

C_ChallengeMode.GetActiveKeystoneInfo(): Retorna el nivel de la piedra, el mapa actual y el tiempo límite total.

C_ChallengeMode.GetDeathCount(): Retorna el número de muertes del grupo para calcular la penalización de tiempo ($deaths \times 5$ segundos).

C_ChallengeMode.GetActiveAffixIDs(): Retorna una tabla con los IDs de afijos activos de la semana para renderizar sus iconos correspondientes.

Eventos Críticos:

SCENARIO_UPDATE / SCENARIO_CRITERIA_UPDATE: Disparados ante cualquier interacción dentro de una gesta o Delve.

CHALLENGE_MODE_START / CHALLENGE_MODE_COMPLETED: Gobiernan el encendido y apagado del reloj de Mythic+.

5. Sistema Unificado de Seguimiento (C_ContentTracking)

El nuevo estándar unificado de Blizzard para rastrear elementos coleccionables (Logros, Monturas, Mascotas, Transfiguraciones) que reemplaza las antiguas llamadas deprecadas de seguimiento individual.

C_ContentTracking
 ├── GetTrackedIDs(ContentTrackingType) ──> trackedIDs (table)
 │    └── Tipos válidos:
 │         ├── Enum.ContentTrackingType.Achievement
 │         ├── Enum.ContentTrackingType.Collectible (Monturas/Mascotas)
 │         └── Enum.ContentTrackingType.Appearance (Transmogs)
 └── IsTracking(ContentTrackingType, ID) ──> isTracked (boolean)


Extracción de Datos de Logros (Bajo Nivel):

GetAchievementInfo(achievementID): Retorna título, descripción, puntos, completado e icono.

GetAchievementCriteriaInfo(achievementID, criteriaIndex): Desglosa los pasos individuales del logro.

Eventos Críticos:

CONTENT_TRACKING_LIST_UPDATE: Se dispara al añadir o remover cualquier elemento de este sistema unificado.

6. Economías y Actividades (C_TradeSkillUI & C_PerksActivities)

Namespace para el farmeo de materiales de profesiones, recetas activas y las tareas mensuales del Registro de Viajero (Trading Post).

C_TradeSkillUI
 ├── GetRecipesTracked() ──> recipeIDs (table)
 ├── GetRecipeInfo(recipeID) ──> recipeInfo (table)
 └── GetRecipeRequirements(recipeID) ──> reagents (table)
      └── [Reagent Node]
           ├── reagentName (string)
           ├── quantityRequired (number)
           └── quantityInventory (calculated via C_Container.GetItemCount)

C_PerksActivities
 ├── GetTrackedActivities() ──> activityIDs (table)
 ├── GetActivityInfo(activityID) ──> title (string), progress (number), maxProgress (number)
 └── GetMonthlyPlayerEarned() ──> currentPoints (number) -- Cap de 1000 puntos


Eventos Críticos:

TRADE_SKILL_LIST_UPDATE: Disparado al cambiar materiales o recetas rastreadas.

PERKS_ACTIVITIES_TRACKED_UPDATED: Disparado al progresar en tareas del Puesto Comercial.

7. Gestor de Widgets de Pantalla (C_UIWidgetManager)

El sistema dinámico que Blizzard usa para inyectar medidores de energía, barras de progreso personalizadas y capturas de bases de PvP sin recurrir a misiones tradicionales.

Métodos Macro:

C_UIWidgetManager.GetTopCenterWidgetSetID(): Retorna el set activo en la zona superior central (ej. progreso de un evento público).

C_UIWidgetManager.GetBelowMinimapWidgetSetID(): Retorna el set activo debajo del minimapa.

Lógica de Renderizado No Invasivo:

Para integrarlos de forma limpia en tu tracker minimalista sin provocar errores asíncronos en el cliente, reparenta el marco del widget directamente a tu contenedor:


$$\text{UIWidgetFrame:SetParent(AscensionObjectiveTracker)}$$

Oculta los bordes pesados de oro nativos de forma segura iterando sus regiones de textura y aplicando:


$$\text{texture:SetAlpha(0)}$$

8. Navegación y Flecha de Guía (C_SuperTrack)

La capa encargada de saber exactamente hacia dónde mira la brújula en pantalla y el marcador tridimensional del mapa del mundo.

Métodos de Super Tracking:

C_SuperTrack.GetSuperTrackedQuestID(): Retorna el ID de la misiones a la que apunta activamente la flecha dorada de navegación de la UI.

C_SuperTrack.SetSuperTrackedQuestID(questID): Cambia de forma forzada el enfoque de la brújula del juego a la misión seleccionada.

C_SuperTrack.SetSuperTrackedUserWaypoint(active): Enciende o apaga el waypoint personalizado del usuario.

Eventos Críticos:

SUPER_TRACKING_CHANGED: Disparado cuando el jugador cambia su objetivo de navegación prioritario en el mapa o tracker.