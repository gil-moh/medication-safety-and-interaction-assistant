Include (%AI, %occStatus)

/// Read-only FHIR medication safety tool.
///
/// Focuses on MVP medication review needs:
/// - active medication list
/// - duplicate therapy detection
/// - medication interaction detection
/// - medication-food interaction cautions
/// - population contraindication cautions (pregnancy, lactation, age)
/// - activity cautions (driving/heavy machinery)
/// - black box warning checks
/// - drug-condition warning checks
/// - mental health condition warnings
/// - family history medication warnings
/// - allergy cross-check
/// - adherence signal hints
///
/// Configure FHIR endpoint with:
///   FHIR_BASE_URL
///   FHIR_BEARER_TOKEN (optional)
///   FHIR_BASIC_USER / FHIR_BASIC_PASS (optional)
Class Sample.AI.Tools.MedicationSafetyReadOnly Extends %AI.Tool
{

Property Name As %String [ InitialExpression = "MedicationSafetyReadOnly" ];
Property Description As %String(MAXLEN = "") [ InitialExpression = "Read-only medication safety review over FHIR resources" ];

/// Get MedicationRequest resources for a patient.
ClassMethod GetMedicationRequests(patientId As %String, status As %String = "active", limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Set max = $SELECT(limit>200:200, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If status '= "" {
        Set query = query _ "&status=" _ ..UrlEncode(status)
    }
    Return ..GetFHIR("MedicationRequest?" _ query)
}

/// Get MedicationStatement resources for a patient.
ClassMethod GetMedicationStatements(patientId As %String, status As %String = "active", limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Set max = $SELECT(limit>200:200, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If status '= "" {
        Set query = query _ "&status=" _ ..UrlEncode(status)
    }
    Return ..GetFHIR("MedicationStatement?" _ query)
}

/// Get AllergyIntolerance resources for a patient.
ClassMethod GetAllergies(patientId As %String, limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Set max = $SELECT(limit>200:200, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    Return ..GetFHIR("AllergyIntolerance?" _ query)
}

/// Get Condition resources for a patient.
ClassMethod GetConditions(patientId As %String, status As %String = "", limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Set max = $SELECT(limit>200:200, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If status '= "" {
        Set query = query _ "&clinical-status=" _ ..UrlEncode(status)
    }
    Return ..GetFHIR("Condition?" _ query)
}

/// Get FamilyMemberHistory resources for a patient.
ClassMethod GetFamilyHistory(patientId As %String, limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Set max = $SELECT(limit>200:200, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    Return ..GetFHIR("FamilyMemberHistory?" _ query)
}

/// Get Observation resources for a patient.
ClassMethod GetObservations(patientId As %String, category As %String = "", limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Set max = $SELECT(limit>200:200, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max _ "&_sort=-date"
    If category '= "" {
        Set query = query _ "&category=" _ ..UrlEncode(category)
    }
    Return ..GetFHIR("Observation?" _ query)
}

/// Get Patient resource.
ClassMethod GetPatient(patientId As %String) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Return ..GetFHIR("Patient/" _ ..UrlEncode(patientId))
}

/// Build a medication safety snapshot for deterministic review.
ClassMethod BuildMedicationReviewSnapshot(patientId As %String, limit As %Integer = 50) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set requests = ..GetMedicationRequests(patientId, "", limit)
    Set statements = ..GetMedicationStatements(patientId, "", limit)
    Set allergies = ..GetAllergies(patientId, limit)
    Set conditions = ..GetConditions(patientId, "", limit)
    Set familyHistory = ..GetFamilyHistory(patientId, limit)
    Set observations = ..GetObservations(patientId, "", limit)
    Set patient = ..GetPatient(patientId)

    Set medList = ..BuildActiveMedicationList(requests, statements)
    Set duplicateFindings = ..DetectDuplicateTherapy(medList)
    Set interactionFindings = ..DetectMedicationInteractions(medList)
    Set foodInteractionFindings = ..DetectFoodInteractions(medList)
    Set populationFindings = ..DetectPopulationContraindications(medList, patient, conditions)
    Set activityFindings = ..DetectActivityCautions(medList, patient, observations)
    Set blackBoxFindings = ..DetectBlackBoxWarnings(medList, patient, conditions)
    Set populationFindings = ..DeduplicatePopulationVsBlackBox(populationFindings, blackBoxFindings)
    Set conditionWarningFindings = ..DetectDrugConditionWarnings(medList, conditions)
    Set labThresholdFindings = ..DetectLabThresholdWarnings(medList, observations)
    Set qtWarningFindings = ..DetectQTWarnings(medList, observations)
    Set anticholinergicBurdenFindings = ..DetectAnticholinergicBurden(medList)
    Set mentalHealthFindings = ..DetectMentalHealthWarnings(medList, conditions)
    Set familyHistoryFindings = ..DetectFamilyHistoryMedicationWarnings(medList, familyHistory)
    Set allergyFindings = ..CrossCheckAllergies(medList, allergies)
    Set adherenceFindings = ..DetectAdherenceSignals(requests, statements, observations)
    Set recommendedActions = ..BuildRecommendedActions(blackBoxFindings, populationFindings, conditionWarningFindings, labThresholdFindings, qtWarningFindings, anticholinergicBurdenFindings, mentalHealthFindings, familyHistoryFindings, interactionFindings, activityFindings, adherenceFindings)

    Return {
        "patientId": (patientId),
        "generatedAt": ($ZDATETIME($HOROLOG, 3, 1)),
        "resourceCounts": {
            "medicationRequests": (..CountBundleEntries(requests)),
            "medicationStatements": (..CountBundleEntries(statements)),
            "allergies": (..CountBundleEntries(allergies)),
            "conditions": (..CountBundleEntries(conditions)),
            "familyHistory": (..CountBundleEntries(familyHistory)),
            "observations": (..CountBundleEntries(observations))
        },
        "activeMedicationList": (medList),
        "duplicateTherapyFindings": (duplicateFindings),
        "medicationInteractionFindings": (interactionFindings),
        "medicationFoodInteractionFindings": (foodInteractionFindings),
        "medicationPopulationContraindicationFindings": (populationFindings),
        "medicationActivityCautionFindings": (activityFindings),
        "medicationBlackBoxWarningFindings": (blackBoxFindings),
        "medicationConditionWarningFindings": (conditionWarningFindings),
        "medicationLabThresholdWarningFindings": (labThresholdFindings),
        "medicationQTWarningFindings": (qtWarningFindings),
        "medicationAnticholinergicBurdenFindings": (anticholinergicBurdenFindings),
        "medicationMentalHealthWarningFindings": (mentalHealthFindings),
        "medicationFamilyHistoryWarningFindings": (familyHistoryFindings),
        "allergyCrossCheckFindings": (allergyFindings),
        "adherenceSignals": (adherenceFindings),
        "recommendedActions": (recommendedActions),
        "vectorSearch": (..GetGuidanceSnippets("medication safety and interaction counseling", 3, medList, blackBoxFindings, familyHistoryFindings, interactionFindings)),
        "raw": {
            "medicationRequests": (requests),
            "medicationStatements": (statements),
            "allergies": (allergies),
            "conditions": (conditions),
            "familyHistory": (familyHistory),
            "observations": (observations),
            "patient": (patient)
        }
    }
}

/// Local fallback hook for contextual guidance snippets.
/// Replace with real IRIS Vector Search retrieval in production.
ClassMethod GetGuidanceSnippets(query As %String, topK As %Integer = 3, medList As %DynamicArray = "", blackBoxFindings As %DynamicArray = "", familyHistoryFindings As %DynamicArray = "", interactionFindings As %DynamicArray = "") As %DynamicObject
{
    Set k = $SELECT(topK>10:10, topK<1:1, 1:topK)
    Set snippets = []

    // High-priority clinical counseling for black-box warnings.
    If $ISOBJECT(blackBoxFindings) && (blackBoxFindings.%Size()>0) {
        Set f = blackBoxFindings.%Get(0)
        If $ISOBJECT(f) {
            Do snippets.%Push({
                "topic": "black-box safety",
                "text": "Boxed warning present. Perform urgent risk mitigation and specialist review before routine counseling.",
                "source": "local-guidance-fallback",
                "score": 0.99
            })
        }
    }

    If $ISOBJECT(interactionFindings) && (interactionFindings.%Size()>0) {
        Do snippets.%Push({
            "topic": "drug-drug interaction counseling",
            "text": "When a major interaction is detected, verify indication, confirm monitoring plan, and educate on red-flag symptoms.",
            "source": "local-guidance-fallback",
            "score": 0.95
        })
    }

    If $ISOBJECT(familyHistoryFindings) && (familyHistoryFindings.%Size()>0) {
        Do snippets.%Push({
            "topic": "family-history risk counseling",
            "text": "Family history can increase susceptibility for harm in selected medications; strengthen follow-up and shared decision counseling.",
            "source": "local-guidance-fallback",
            "score": 0.93
        })
    }

    If $ISOBJECT(medList) && (medList.%Size()>0) {
        Do snippets.%Push({
            "topic": "medication reconciliation",
            "text": "Review each active medication for indication, adherence, and duplication; reconcile MedicationRequest with patient-reported use.",
            "source": "local-guidance-fallback",
            "score": 0.90
        })
    }

    If snippets.%Size()=0 {
        Do snippets.%Push({
            "topic": "general medication safety",
            "text": "No high-priority contextual snippets were matched. Continue standard medication safety review and counseling.",
            "source": "local-guidance-fallback",
            "score": 0.70
        })
    }

    Set limited = []
    For i=0:1:(k-1) {
        If i>=snippets.%Size() {
            Continue
        }
        Do limited.%Push(snippets.%Get(i))
    }

    Return {
        "enabled": (1),
        "mode": "local-guidance-fallback",
        "topK": (k),
        "query": (query),
        "status": "enabled-local-fallback",
        "hint": "Fallback snippets are active. Replace this method with IRIS Vector Search retrieval for semantic ranking over your guidance corpus.",
        "snippets": (limited)
    }
}

ClassMethod BuildActiveMedicationList(requestBundle As %DynamicObject, statementBundle As %DynamicObject = "") As %DynamicArray [ Internal ]
{
    Set out = []

    Do ..AppendMedicationEntries(out, requestBundle, "MedicationRequest")
    If $ISOBJECT(statementBundle) {
        Do ..AppendMedicationEntries(out, statementBundle, "MedicationStatement")
    }

    Return out
}

ClassMethod AppendMedicationEntries(ByRef out As %DynamicArray, bundle As %DynamicObject, sourceType As %String) [ Internal ]
{
    If '$ISOBJECT(bundle) {
        Quit
    }

    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Quit
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }

        Set medName = ..ExtractMedicationName(r)
        If medName = "" {
            Continue
        }

        Set one = {
            "name": (medName),
            "normalizedKey": (..NormalizeMedicationKey(medName)),
            "rxnormCode": (..ExtractRxNormCode(r)),
            "resourceId": (..SafeGet(r, "id")),
            "status": (..SafeGet(r, "status")),
            "source": (sourceType),
            "authoredOn": (..SafeGet(r, "authoredOn")),
            "effectiveDateTime": (..SafeGet(r, "effectiveDateTime"))
        }
        Do out.%Push(one)
    }
}

ClassMethod DetectDuplicateTherapy(medList As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Kill keyCount, keyNames, keyIds
    For i=0:1:(medList.%Size()-1) {
        Set one = medList.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }
        Set key = ..SafeGet(one, "normalizedKey")
        Set name = ..SafeGet(one, "name")
        If (key = "") || (name = "") {
            Continue
        }
        Set keyCount(key) = $Get(keyCount(key)) + 1
        Set keyNames(key, keyCount(key)) = name
        Set keyIds(key, keyCount(key)) = ..SafeGet(one, "resourceId")
    }

    Set key = ""
    For {
        Set key = $Order(keyCount(key))
        Quit:key=""
        If $Get(keyCount(key))<2 {
            Continue
        }
        Set names = ""
        Set ids = []
        For idx=1:1:keyCount(key) {
            Set n = $Get(keyNames(key, idx))
            If n = "" {
                Continue
            }
            If names = "" {
                Set names = n
            } Else {
                Set names = names _ "; " _ n
            }

            Set rid = $Get(keyIds(key, idx))
            If rid '= "" {
                Do ids.%Push(rid)
            }
        }
        Do findings.%Push({
            "risk": "possible-duplicate-therapy",
            "key": (key),
            "count": (keyCount(key)),
            "evidence": (names),
            "resourceIds": (ids),
            "source": {
                "type": "heuristic",
                "method": "normalized-medication-name-match",
                "resources": "MedicationRequest/MedicationStatement"
            },
            "message": "Potential duplicate therapy detected. Review overlapping active medications."
        })
    }

    Return findings
}

/// Remove overlapping population findings when a stricter black-box warning exists for the same medication and population.
ClassMethod DeduplicatePopulationVsBlackBox(populationFindings As %DynamicArray, blackBoxFindings As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set out = []
    If '$ISOBJECT(populationFindings) {
        Return out
    }

    Kill bb
    If $ISOBJECT(blackBoxFindings) {
        For i=0:1:(blackBoxFindings.%Size()-1) {
            Set one = blackBoxFindings.%Get(i)
            If '$ISOBJECT(one) {
                Continue
            }
            Set medId = ..SafeGet(one, "medicationResourceId")
            Set pop = ..SafeGet(one, "population")
            If medId = "" {
                Continue
            }
            If pop = "" {
                Set pop = "all"
            }
            Set bb(medId, pop) = 1
            Set bb(medId, "all") = 1
        }
    }

    For i=0:1:(populationFindings.%Size()-1) {
        Set one = populationFindings.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }
        Set medId = ..SafeGet(one, "medicationResourceId")
        Set pop = ..SafeGet(one, "population")
        If medId '= "", (pop '= ""), $Get(bb(medId, pop)) {
            Continue
        }
        If medId '= "", $Get(bb(medId, "all")) {
            Continue
        }
        Do out.%Push(one)
    }

    Return out
}

/// Detect potential medication-medication interactions from a local knowledge table.
ClassMethod DetectMedicationInteractions(medList As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()<2) {
        Return findings
    }

    Set rules = ..GetInteractionRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-2) {
        Set a = medList.%Get(i)
        If '$ISOBJECT(a) {
            Continue
        }
        Set keyA = ..SafeGet(a, "normalizedKey")
        Set nameA = ..SafeGet(a, "name")
        Set idA = ..SafeGet(a, "resourceId")

        For j=i+1:1:(medList.%Size()-1) {
            Set b = medList.%Get(j)
            If '$ISOBJECT(b) {
                Continue
            }
            Set keyB = ..SafeGet(b, "normalizedKey")
            Set nameB = ..SafeGet(b, "name")
            Set idB = ..SafeGet(b, "resourceId")

            For r=0:1:(rules.%Size()-1) {
                Set rule = rules.%Get(r)
                If '$ISOBJECT(rule) {
                    Continue
                }

                Set ra = ..SafeGet(rule, "a")
                Set rb = ..SafeGet(rule, "b")
                Set matchAB = (..ContainsInsensitive(keyA, ra) && ..ContainsInsensitive(keyB, rb))
                Set matchBA = (..ContainsInsensitive(keyA, rb) && ..ContainsInsensitive(keyB, ra))
                If '(matchAB || matchBA) {
                    Continue
                }

                Set sig = ..SafeGet(rule, "id") _ "|" _ $Select(idA<idB:idA_"|"_idB, 1:idB_"|"_idA)
                If $Get(seen(sig)) {
                    Continue
                }
                Set seen(sig) = 1

                Do findings.%Push({
                    "risk": "possible-drug-drug-interaction",
                    "severity": (..SafeGet(rule, "severity")),
                    "medicationA": (nameA),
                    "medicationB": (nameB),
                    "medicationAResourceId": (idA),
                    "medicationBResourceId": (idB),
                    "message": (..SafeGet(rule, "message")),
                    "source": {
                        "type": "knowledge-base",
                        "table": "local-medication-interaction-rules-v1",
                        "ruleId": (..SafeGet(rule, "id")),
                        "reference": (..SafeGet(rule, "reference"))
                    }
                })
            }
        }
    }

    Return findings
}

ClassMethod GetInteractionRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "ddi-warfarin-aspirin",
        "mode": "strict",
        "a": "warfarin",
        "b": "aspirin",
        "severity": "high",
        "message": "Warfarin with aspirin may significantly increase bleeding risk. Verify indication and monitoring plan.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "ddi-warfarin-ibuprofen",
        "mode": "strict",
        "a": "warfarin",
        "b": "ibuprofen",
        "severity": "high",
        "message": "Warfarin with ibuprofen may increase bleeding risk. Consider safer analgesic alternatives.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "ddi-clopidogrel-omeprazole",
        "mode": "conservative",
        "a": "clopidogrel",
        "b": "omeprazole",
        "severity": "moderate",
        "message": "Clopidogrel with omeprazole may reduce antiplatelet effect; review PPI choice.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "ddi-ace-spironolactone",
        "mode": "conservative",
        "a": "ramipril",
        "b": "spironolactone",
        "severity": "moderate",
        "message": "ACE inhibitor plus spironolactone may increase hyperkalemia risk; monitor potassium and renal function.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect potential medication-food interactions from a local counseling rule table.
ClassMethod DetectFoodInteractions(medList As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Set rules = ..GetFoodInteractionRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }

        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }

            Set medMatch = ..MedicationMatchesRule(rule, key, rxCode)
            If 'medMatch {
                Continue
            }

            Set sig = ..SafeGet(rule, "id") _ "|" _ medId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Do findings.%Push({
                "risk": "possible-medication-food-interaction",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "foodOrSubstance": (..SafeGet(rule, "food")),
                "timing": (..SafeGet(rule, "timing")),
                "requiresDietaryConfirmation": 1,
                "message": (..SafeGet(rule, "message")),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-food-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetFoodInteractionRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "food-levothyroxine-dairy-calcium",
        "mode": "conservative",
        "med": "levothyroxine",
        "rxnormCode": "966251",
        "food": "dairy or calcium-rich foods/supplements",
        "timing": "separate by at least 4 hours",
        "severity": "moderate",
        "message": "Levothyroxine absorption may be reduced by dairy or calcium products. Prefer an empty stomach and separate calcium-containing intake.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "food-doxycycline-dairy",
        "mode": "conservative",
        "med": "doxycycline",
        "food": "milk, yogurt, or other dairy",
        "timing": "separate by at least 2 hours",
        "severity": "moderate",
        "message": "Doxycycline absorption can decrease when taken with dairy. Counsel on dose timing around meals and dairy intake.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "food-simvastatin-grapefruit",
        "mode": "strict",
        "med": "simvastatin",
        "food": "grapefruit or grapefruit juice",
        "timing": "avoid regular grapefruit intake",
        "severity": "high",
        "message": "Simvastatin exposure can increase with grapefruit, raising myopathy risk. Consider avoidance and counseling.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "food-warfarin-vitamin-k",
        "mode": "conservative",
        "med": "warfarin",
        "food": "large changes in vitamin K rich foods",
        "timing": "keep intake consistent day-to-day",
        "severity": "moderate",
        "message": "Warfarin effect can vary with major vitamin K intake changes. Counsel on consistent dietary patterns and INR follow-up.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect population-based contraindication cautions (pregnancy, lactation, pediatric age).
ClassMethod DetectPopulationContraindications(medList As %DynamicArray, patient As %DynamicObject, conditionBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Set factors = ..ExtractPatientFactors(patient, conditionBundle)
    Set rules = ..GetPopulationContraindicationRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }

        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }

            Set ruleMed = ..SafeGet(rule, "med")
            Set ruleRx = ..SafeGet(rule, "rxnormCode")
            Set medMatch = ..ContainsInsensitive(key, ruleMed)
            If 'medMatch, (ruleRx '= ""), (rxCode '= "") {
                Set medMatch = (rxCode = ruleRx)
            }
            If 'medMatch {
                Continue
            }

            Set pop = ..SafeGet(rule, "population")
            Set applies = 0
            If pop = "pregnancy" {
                Set applies = (+..SafeGet(factors, "pregnant")=1)
            } ElseIf pop = "lactation" {
                Set applies = (+..SafeGet(factors, "lactating")=1)
            } ElseIf pop = "under-age" {
                Set ageYears = +..SafeGet(factors, "ageYears")
                Set maxAge = +..SafeGet(rule, "maxAgeExclusive")
                If (ageYears'<0) && (maxAge>0) && (ageYears<maxAge) {
                    Set applies = 1
                }
            }
            If 'applies {
                Continue
            }

            Set sig = ..SafeGet(rule, "id") _ "|" _ medId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Do findings.%Push({
                "risk": "possible-population-contraindication",
                "mode": (..SafeGet(rule, "mode")),
                "population": (pop),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "criterion": (..SafeGet(rule, "criterion")),
                "message": (..SafeGet(rule, "message")),
                "requiresPopulationConfirmation": 1,
                "patientFactors": {
                    "ageYears": (+..SafeGet(factors, "ageYears")),
                    "sex": (..SafeGet(factors, "sex")),
                    "pregnant": (+..SafeGet(factors, "pregnant")),
                    "lactating": (+..SafeGet(factors, "lactating"))
                },
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-population-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetPopulationContraindicationRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "pop-valproate-pregnancy",
        "mode": "strict",
        "population": "pregnancy",
        "med": "valproate",
        "criterion": "pregnant",
        "severity": "high",
        "message": "Valproate is generally contraindicated in pregnancy due to fetal risk. Urgent specialist review is recommended.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "pop-isotretinoin-pregnancy",
        "mode": "strict",
        "population": "pregnancy",
        "med": "isotretinoin",
        "criterion": "pregnant",
        "severity": "high",
        "message": "Isotretinoin is contraindicated in pregnancy due to severe teratogenic risk.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "pop-codeine-under-12",
        "mode": "strict",
        "population": "under-age",
        "med": "codeine",
        "maxAgeExclusive": 12,
        "criterion": "age < 12",
        "severity": "high",
        "message": "Codeine is not recommended under age 12 because of serious respiratory risk.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "pop-doxycycline-under-8",
        "mode": "conservative",
        "population": "under-age",
        "med": "doxycycline",
        "maxAgeExclusive": 8,
        "criterion": "age < 8",
        "severity": "moderate",
        "message": "Doxycycline use under age 8 requires careful indication review and age-specific guidance.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "pop-lithium-lactation",
        "mode": "conservative",
        "population": "lactation",
        "med": "lithium",
        "criterion": "breastfeeding",
        "severity": "moderate",
        "message": "Lithium during breastfeeding may pose infant exposure risk. Confirm feeding status and specialist plan.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect activity cautions related to driving and heavy machinery.
ClassMethod DetectActivityCautions(medList As %DynamicArray, patient As %DynamicObject = "", observationBundle As %DynamicObject = "") As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Set occupationProfile = ..ExtractOccupationProfile(patient, observationBundle)
    Set occ = ..SafeGet(occupationProfile, "occupation")
    Set occSource = ..SafeGet(occupationProfile, "source")
    Set occSensitive = (+..SafeGet(occupationProfile, "isSafetySensitive")=1)

    Set rules = ..GetActivityCautionRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }

        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }

            Set ruleMed = ..SafeGet(rule, "med")
            Set ruleRx = ..SafeGet(rule, "rxnormCode")
            Set medMatch = ..ContainsInsensitive(key, ruleMed)
            If 'medMatch, (ruleRx '= ""), (rxCode '= "") {
                Set medMatch = (rxCode = ruleRx)
            }
            If 'medMatch {
                Continue
            }

            Set sig = ..SafeGet(rule, "id") _ "|" _ medId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Set msg = ..SafeGet(rule, "message")
            If occSensitive, (occ '= "") {
                Set msg = msg _ " Reported occupation ('" _ occ _ "') appears safety-sensitive; prioritize work-task counseling."
            }

            Do findings.%Push({
                "risk": "possible-activity-impairment",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "activity": (..SafeGet(rule, "activity")),
                "criterion": (..SafeGet(rule, "criterion")),
                "requiresActivityCounseling": 1,
                "message": (msg),
                "occupation": (occ),
                "occupationSource": (occSource),
                "occupationSafetySensitive": (+occSensitive),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-activity-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetActivityCautionRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "act-diazepam-driving",
        "mode": "strict",
        "med": "diazepam",
        "rxnormCode": "3322",
        "activity": "driving or operating heavy machinery",
        "criterion": "sedation/psychomotor impairment risk",
        "severity": "high",
        "message": "Diazepam can impair alertness and reaction time. Advise avoiding driving or operating heavy machinery until effects are known.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "act-zolpidem-driving",
        "mode": "strict",
        "med": "zolpidem",
        "activity": "driving or operating heavy machinery",
        "criterion": "next-day drowsiness risk",
        "severity": "high",
        "message": "Zolpidem may cause next-day drowsiness and slowed reaction. Counsel against driving or hazardous activities if not fully alert.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "act-codeine-driving",
        "mode": "strict",
        "med": "codeine",
        "rxnormCode": "2670",
        "activity": "driving or operating heavy machinery",
        "criterion": "opioid-related sedation risk",
        "severity": "moderate",
        "message": "Codeine may cause drowsiness and impaired concentration. Use caution with driving and machinery operation.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "act-diphenhydramine-driving",
        "mode": "conservative",
        "med": "diphenhydramine",
        "activity": "driving or operating heavy machinery",
        "criterion": "antihistamine sedation risk",
        "severity": "moderate",
        "message": "Diphenhydramine can reduce alertness. Counsel to avoid driving or hazardous tasks when drowsy.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect highest-severity boxed warnings using local curated rules.
ClassMethod DetectBlackBoxWarnings(medList As %DynamicArray, patient As %DynamicObject, conditionBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Set factors = ..ExtractPatientFactors(patient, conditionBundle)
    Set rules = ..GetBlackBoxWarningRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }

        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }

            Set ruleMed = ..SafeGet(rule, "med")
            Set ruleRx = ..SafeGet(rule, "rxnormCode")
            Set medMatch = ..ContainsInsensitive(key, ruleMed)
            If 'medMatch, (ruleRx '= ""), (rxCode '= "") {
                Set medMatch = (rxCode = ruleRx)
            }
            If 'medMatch {
                Continue
            }

            Set pop = ..SafeGet(rule, "population")
            Set popApplies = 1
            If pop = "pregnancy" {
                Set popApplies = (+..SafeGet(factors, "pregnant")=1)
            } ElseIf pop = "lactation" {
                Set popApplies = (+..SafeGet(factors, "lactating")=1)
            }
            If 'popApplies {
                Continue
            }

            Set sig = ..SafeGet(rule, "id") _ "|" _ medId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Do findings.%Push({
                "risk": "black-box-warning",
                "mode": "strict",
                "severity": "critical",
                "medication": (medName),
                "medicationResourceId": (medId),
                "population": (pop),
                "warningType": (..SafeGet(rule, "warningType")),
                "message": (..SafeGet(rule, "message")),
                "action": (..SafeGet(rule, "action")),
                "patientFactors": {
                    "ageYears": (+..SafeGet(factors, "ageYears")),
                    "sex": (..SafeGet(factors, "sex")),
                    "pregnant": (+..SafeGet(factors, "pregnant")),
                    "lactating": (+..SafeGet(factors, "lactating"))
                },
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-black-box-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetBlackBoxWarningRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "bbw-isotretinoin-pregnancy",
        "mode": "strict",
        "population": "pregnancy",
        "med": "isotretinoin",
        "warningType": "teratogenicity",
        "message": "Isotretinoin (Accutane) has a boxed warning for severe fetal harm and is contraindicated in pregnancy.",
        "action": "Urgent stop/review with specialist and pregnancy risk protocol.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "bbw-clozapine-neutropenia",
        "mode": "strict",
        "population": "all",
        "med": "clozapine",
        "warningType": "severe-neutropenia",
        "message": "Clozapine has boxed warning-level hematologic risk and requires strict monitoring protocols.",
        "action": "Verify monitoring program adherence and recent blood counts before continuation.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect medication-condition cautions from local interaction rules.
ClassMethod DetectDrugConditionWarnings(medList As %DynamicArray, conditionBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }
    If '$ISOBJECT(conditionBundle) {
        Return findings
    }

    Set condIndex = ..BuildConditionIndex(conditionBundle)
    If '$ISOBJECT(condIndex) || (condIndex.%Size()=0) {
        Return findings
    }

    Set rules = ..GetDrugConditionRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }

        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }

            Set ruleMed = ..SafeGet(rule, "med")
            Set ruleRx = ..SafeGet(rule, "rxnormCode")
            Set medMatch = ..ContainsInsensitive(key, ruleMed)
            If 'medMatch, (ruleRx '= ""), (rxCode '= "") {
                Set medMatch = (rxCode = ruleRx)
            }
            If 'medMatch {
                Continue
            }

            Set condCode = ..SafeGet(rule, "conditionCode")
            Set condKeyword = ..SafeGet(rule, "conditionKeyword")
            Set condHit = ..FindConditionHit(condIndex, condCode, condKeyword)
            If '$ISOBJECT(condHit) {
                Continue
            }

            Set condId = ..SafeGet(condHit, "conditionId")
            Set sig = ..SafeGet(rule, "id") _ "|" _ medId _ "|" _ condId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Set dcCondText = ..SafeGet(condHit, "conditionText")
            Set dcReasoning = "Warning for " _ medName _ " because patient has a recorded condition: " _ dcCondText _ "."

            Do findings.%Push({
                "risk": "possible-drug-condition-warning",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "condition": (dcCondText),
                "conditionCode": (..SafeGet(condHit, "conditionCode")),
                "conditionResourceId": (condId),
                "reasoning": (dcReasoning),
                "message": (..SafeGet(rule, "message")),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-condition-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetDrugConditionRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    // General family-level rules (apply to multiple medications).
    Do rules.%Push({
        "id": "dc-family-nsaid-kidney",
        "mode": "strict",
        "medFamily": "nsaid",
        "conditionKeyword": "kidney",
        "severity": "high",
        "message": "NSAID-class medications may worsen kidney function when renal disease is present. Reassess analgesic strategy and renal monitoring.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-family-hepatotoxic-liver",
        "mode": "strict",
        "medFamily": "hepatotoxic-risk",
        "conditionKeyword": "liver",
        "severity": "high",
        "message": "This medication has meaningful hepatic risk potential in liver disease. Reassess regimen and liver monitoring plan.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-family-gi-malabsorption",
        "mode": "strict",
        "medFamily": "diarrhea-malabsorption-risk",
        "conditionKeyword": "malabsorption",
        "severity": "high",
        "message": "This medication may worsen diarrhea or nutrient absorption problems in patients with malabsorption syndromes.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-nsaid-ckd",
        "mode": "strict",
        "med": "ibuprofen",
        "rxnormCode": "5640",
        "conditionCode": "709044004",
        "conditionKeyword": "chronic kidney",
        "severity": "high",
        "message": "NSAID use in chronic kidney disease may worsen renal function. Review alternatives and monitor kidney function.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-methotrexate-chronic-liver-disease",
        "mode": "strict",
        "med": "methotrexate",
        "conditionKeyword": "chronic liver",
        "severity": "high",
        "message": "Methotrexate in chronic liver disease can increase hepatotoxicity risk. Reassess indication and liver monitoring strategy.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-acetaminophen-cirrhosis",
        "mode": "conservative",
        "med": "acetaminophen",
        "conditionKeyword": "cirrhosis",
        "severity": "moderate",
        "message": "Acetaminophen in cirrhosis may require careful dose limits and monitoring. Confirm cumulative daily dose across products.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-beta-blocker-asthma",
        "mode": "strict",
        "med": "propranolol",
        "conditionCode": "195967001",
        "conditionKeyword": "asthma",
        "severity": "moderate",
        "message": "Non-selective beta blockers may exacerbate asthma. Reassess agent choice and respiratory status.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-metformin-advanced-ckd",
        "mode": "conservative",
        "med": "metformin",
        "conditionKeyword": "chronic kidney",
        "severity": "moderate",
        "message": "Metformin with advanced kidney impairment may require dose change or discontinuation per renal thresholds.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "dc-orlistat-malabsorption",
        "mode": "strict",
        "med": "orlistat",
        "conditionKeyword": "malabsorption",
        "severity": "high",
        "message": "Orlistat can increase fat malabsorption and diarrhea-related nutrient loss; existing malabsorption may worsen. Review suitability and nutrition monitoring.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect medication risks amplified by measured lab thresholds (kidney and liver examples).
ClassMethod DetectLabThresholdWarnings(medList As %DynamicArray, observationBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }
    If '$ISOBJECT(observationBundle) {
        Return findings
    }

    Set labIndex = ..BuildObservationLabIndex(observationBundle)
    If '$ISOBJECT(labIndex) || (labIndex.%Size()=0) {
        Return findings
    }

    Set rules = ..GetLabThresholdRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }

        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }
            If '..MedicationMatchesRule(rule, key, rxCode) {
                Continue
            }

            Set labHit = ..FindLabHit(labIndex, ..SafeGet(rule, "loincCode"), ..SafeGet(rule, "labKeyword"), ..SafeGet(rule, "minValueInclusive"), ..SafeGet(rule, "maxValueExclusive"))
            If '$ISOBJECT(labHit) {
                Continue
            }

            Set labObsId = ..SafeGet(labHit, "observationId")
            Set sig = ..SafeGet(rule, "id") _ "|" _ medId _ "|" _ labObsId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Set labName = ..SafeGet(labHit, "labText")
            Set labValue = ..SafeGet(labHit, "value")
            Set labUnit = ..SafeGet(labHit, "unit")
            Set labReason = "Warning for " _ medName _ " because " _ labName _ " is " _ labValue _ " " _ labUnit _ "."

            Do findings.%Push({
                "risk": "possible-lab-threshold-medication-warning",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "labName": (labName),
                "labCode": (..SafeGet(labHit, "labCode")),
                "labObservationId": (labObsId),
                "labValue": (labValue),
                "labUnit": (labUnit),
                "reasoning": (labReason),
                "message": (..SafeGet(rule, "message")),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-lab-threshold-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetLabThresholdRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "lab-nsaid-egfr-below-30",
        "mode": "strict",
        "medFamily": "nsaid",
        "loincCode": "33914-3",
        "labKeyword": "glomerular filtration rate",
        "maxValueExclusive": 30,
        "severity": "high",
        "message": "eGFR below 30 suggests high renal risk with NSAID therapy. Reassess analgesic choice and renal plan.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "lab-metformin-egfr-below-30",
        "mode": "strict",
        "med": "metformin",
        "loincCode": "33914-3",
        "labKeyword": "glomerular filtration rate",
        "maxValueExclusive": 30,
        "severity": "high",
        "message": "Very low eGFR may require metformin stop/review due to accumulation risk. Follow renal dosing protocol.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "lab-hepatotoxic-alt-above-120",
        "mode": "conservative",
        "medFamily": "hepatotoxic-risk",
        "loincCode": "1742-6",
        "labKeyword": "alanine aminotransferase",
        "minValueInclusive": 120,
        "severity": "high",
        "message": "Marked ALT elevation raises concern for hepatic injury with hepatotoxic-risk medications. Reassess regimen and monitoring urgently.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect QT-risk medication cautions and higher-risk combinations.
ClassMethod DetectQTWarnings(medList As %DynamicArray, observationBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Set rules = ..GetQTRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Set labIndex = ..BuildObservationLabIndex(observationBundle)
    Set lowK = ..FindLabHit(labIndex, "2823-3", "potassium", "", 3.5)
    Set lowKText = ""
    If $ISOBJECT(lowK) {
        Set lowKText = " Low potassium is present (" _ ..SafeGet(lowK, "value") _ " " _ ..SafeGet(lowK, "unit") _ "), which can amplify QT risk."
    }

    Kill seen, qtMedSeen
    Set qtCount = 0
    Set qtList = []
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }
        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        Set isQT = 0
        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }
            If '..MedicationMatchesRule(rule, key, rxCode) {
                Continue
            }

            Set isQT = 1
            Set sig = ..SafeGet(rule, "id") _ "|" _ medId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Set reason = "Warning for " _ medName _ " because this medication has known QT-prolongation risk." _ lowKText

            Do findings.%Push({
                "risk": "possible-qt-prolongation-medication-warning",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "reasoning": (reason),
                "message": (..SafeGet(rule, "message") _ lowKText),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-medication-qt-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }

        If isQT, ('$Get(qtMedSeen(medId))) {
            Set qtMedSeen(medId) = 1
            Set qtCount = qtCount + 1
            Do qtList.%Push({"name":(medName),"resourceId":(medId)})
        }
    }

    If qtCount>1 {
        Set reason = "Warning because patient is on " _ qtCount _ " QT-risk medications at the same time."
        If lowKText '= "" {
            Set reason = reason _ lowKText
        }
        Do findings.%Push({
            "risk": "possible-qt-prolongation-combination-warning",
            "mode": "strict",
            "severity": "high",
            "qtMedicationCount": (qtCount),
            "qtMedications": (qtList),
            "reasoning": (reason),
            "message": ("Concurrent QT-risk medications increase arrhythmia risk. Consider ECG and electrolyte review before continuation." _ lowKText),
            "source": {
                "type": "heuristic",
                "method": "qt-risk-medication-count",
                "reference": "local-curated-rule"
            }
        })
    }

    Return findings
}

ClassMethod GetQTRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "qt-citalopram",
        "mode": "conservative",
        "med": "citalopram",
        "severity": "moderate",
        "message": "Citalopram may prolong QT at higher exposure or with risk factors.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "qt-haloperidol",
        "mode": "strict",
        "med": "haloperidol",
        "severity": "high",
        "message": "Haloperidol is associated with clinically significant QT prolongation risk.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "qt-methadone",
        "mode": "strict",
        "med": "methadone",
        "severity": "high",
        "message": "Methadone can prolong QT and warrants rhythm/electrolyte awareness.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "qt-ziprasidone",
        "mode": "strict",
        "med": "ziprasidone",
        "severity": "high",
        "message": "Ziprasidone has meaningful QT liability, especially with additional risk factors.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Compute anticholinergic burden from active medications.
ClassMethod DetectAnticholinergicBurden(medList As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }

    Set total = 0
    Set contributors = []
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }
        Set medName = ..SafeGet(med, "name")
        Set score = ..GetAnticholinergicScore(medName)
        If score<1 {
            Continue
        }
        Set total = total + score
        Do contributors.%Push({
            "medication": (medName),
            "medicationResourceId": (..SafeGet(med, "resourceId")),
            "score": (score)
        })
    }

    If total<1 {
        Return findings
    }

    Set mode = $Select(total'<3:"strict", 1:"conservative")
    Set severity = $Select(total'<6:"high", total'<3:"moderate", 1:"low")
    Set msg = "Combined anticholinergic burden score is " _ total _ "."
    If total'<3 {
        Set msg = msg _ " Elevated burden may increase confusion, constipation, urinary retention, and fall risk."
    } Else {
        Set msg = msg _ " Low-level burden present; reassess if cognitive or urinary side effects appear."
    }

    Do findings.%Push({
        "risk": "possible-anticholinergic-burden",
        "mode": (mode),
        "severity": (severity),
        "totalScore": (total),
        "contributorCount": (contributors.%Size()),
        "contributors": (contributors),
        "reasoning": ("Warning because summed anticholinergic burden score is " _ total _ "."),
        "message": (msg),
        "source": {
            "type": "knowledge-base",
            "table": "local-anticholinergic-burden-rules-v1",
            "reference": "local-curated-rule"
        }
    })

    Return findings
}

ClassMethod GetAnticholinergicScore(medName As %String) As %Integer [ Internal ]
{
    Set t = $ZCVT(medName, "L")
    If t = "" {
        Return 0
    }
    If (t [ "diphenhydramine") || (t [ "amitriptyline") || (t [ "oxybutynin") || (t [ "doxylamine") || (t [ "paroxetine") {
        Return 3
    }
    If (t [ "hydroxyzine") || (t [ "cyclobenzaprine") || (t [ "olanzapine") {
        Return 2
    }
    If (t [ "cetirizine") || (t [ "nortriptyline") {
        Return 1
    }
    Return 0
}

ClassMethod BuildObservationLabIndex(observationBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set out = []
    If '$ISOBJECT(observationBundle) {
        Return out
    }

    Set entries = observationBundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return out
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }
        If $ZCVT(..SafeGet(r, "resourceType"), "L") '= "observation" {
            Continue
        }

        Set val = ..ExtractObservationNumericValue(r)
        If val = "" {
            Continue
        }

        Set codeObj = r.%Get("code")
        Set codeTxt = ..ExtractCodeableText(codeObj)
        Set code = ..ExtractFirstCodingCode(codeObj)
        Set vq = r.%Get("valueQuantity")
        Set unit = ""
        If $ISOBJECT(vq) {
            Set unit = ..SafeGet(vq, "unit")
            If unit = "" {
                Set unit = ..SafeGet(vq, "code")
            }
        }

        Do out.%Push({
            "observationId": (..SafeGet(r, "id")),
            "labCode": (code),
            "labText": (codeTxt),
            "value": (val),
            "unit": (unit)
        })
    }

    Return out
}

ClassMethod FindLabHit(labIndex As %DynamicArray, loincCode As %String = "", labKeyword As %String = "", minValueInclusive As %Numeric = "", maxValueExclusive As %Numeric = "") As %DynamicObject [ Internal ]
{
    If '$ISOBJECT(labIndex) || (labIndex.%Size()=0) {
        Return ""
    }

    For i=0:1:(labIndex.%Size()-1) {
        Set one = labIndex.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }

        Set c = ..SafeGet(one, "labCode")
        Set t = ..SafeGet(one, "labText")
        Set v = +..SafeGet(one, "value")

        Set codeMatch = 0
        If loincCode '= "" {
            Set codeMatch = (c = loincCode)
        }
        Set textMatch = 0
        If labKeyword '= "" {
            Set textMatch = ..ContainsInsensitive(t, labKeyword)
        }
        If '(codeMatch || textMatch) {
            Continue
        }

        Set passMin = 1
        If minValueInclusive '= "" {
            Set passMin = (v>=+minValueInclusive)
        }
        Set passMax = 1
        If maxValueExclusive '= "" {
            Set passMax = (v<+maxValueExclusive)
        }
        If '(passMin && passMax) {
            Continue
        }

        Return one
    }

    Return ""
}

ClassMethod ExtractObservationNumericValue(obs As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(obs) {
        Return ""
    }

    Set vq = obs.%Get("valueQuantity")
    If $ISOBJECT(vq) {
        Set q = ..SafeGet(vq, "value")
        If q '= "" {
            Return q
        }
    }

    Set vi = ..SafeGet(obs, "valueInteger")
    If vi '= "" {
        Return vi
    }
    Set vd = ..SafeGet(obs, "valueDecimal")
    If vd '= "" {
        Return vd
    }
    Return ""
}

ClassMethod ExtractFirstCodingCode(cc As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(cc) {
        Return ""
    }
    Set coding = cc.%Get("coding")
    If '$ISOBJECT(coding) || (coding.%Size()=0) {
        Return ""
    }
    Set first = coding.%Get(0)
    If '$ISOBJECT(first) {
        Return ""
    }
    Return ..SafeGet(first, "code")
}

ClassMethod BuildRecommendedActions(blackBoxFindings As %DynamicArray, populationFindings As %DynamicArray, conditionFindings As %DynamicArray, labFindings As %DynamicArray, qtFindings As %DynamicArray, anticholinergicFindings As %DynamicArray, mentalHealthFindings As %DynamicArray, familyHistoryFindings As %DynamicArray, interactionFindings As %DynamicArray, activityFindings As %DynamicArray, adherenceFindings As %DynamicArray) As %DynamicArray [ Internal ]
{
    Set out = []
    Kill seen

    If $ISOBJECT(blackBoxFindings) {
        For i=0:1:(blackBoxFindings.%Size()-1) {
            Set one = blackBoxFindings.%Get(i)
            If '$ISOBJECT(one) {
                Continue
            }
            Set med = ..SafeGet(one, "medication")
            Set actionText = ..SafeGet(one, "action")
            If actionText = "" {
                Set actionText = "Urgent specialist review for black-box risk"
            }
            Set full = med _ ": " _ actionText
            Do ..AddStructuredAction(.out, .seen, "stop", "urgent", 4, full, "black-box-warning")
            Set consultText = "Urgent specialist consult for " _ med _ " black-box risk and mitigation plan."
            Do ..AddStructuredAction(.out, .seen, "consult", "urgent", 12, consultText, "black-box-warning")
        }
    }

    Do ..AppendRecommendedActionsFromFindings(.out, .seen, labFindings, "possible-lab-threshold-medication-warning", "high", "labs", 24)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, qtFindings, "possible-qt-prolongation-medication-warning", "high", "ecg", 4)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, anticholinergicFindings, "possible-anticholinergic-burden", "routine", "monitor", 168)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, conditionFindings, "possible-drug-condition-warning", "high", "consult", 24)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, interactionFindings, "possible-drug-drug-interaction", "high", "consult", 8)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, populationFindings, "possible-population-contraindication", "high", "consult", 8)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, activityFindings, "possible-activity-impairment", "routine", "monitor", 72)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, mentalHealthFindings, "possible-mental-health-medication-warning", "routine", "monitor", 72)
    Do ..AppendRecommendedActionsFromFindings(.out, .seen, familyHistoryFindings, "possible-family-history-medication-warning", "routine", "monitor", 168)

    If $ISOBJECT(adherenceFindings) {
        For i=0:1:(adherenceFindings.%Size()-1) {
            Set one = adherenceFindings.%Get(i)
            If '$ISOBJECT(one) {
                Continue
            }
            Set risk = ..SafeGet(one, "risk")
            If risk = "possible-adherence-gap" {
                Set full = "Perform medication reconciliation and adherence interview."
                Do ..AddStructuredAction(.out, .seen, "monitor", "routine", 72, full, "possible-adherence-gap")
            }
            If risk = "possible-stale-prescription" {
                Set med = ..SafeGet(one, "medication")
                Set full = "Confirm active use of " _ med _ " and renew/discontinue outdated orders."
                Do ..AddStructuredAction(.out, .seen, "monitor", "routine", 72, full, "possible-stale-prescription")
            }
        }
    }

    Return out
}

ClassMethod AppendRecommendedActionsFromFindings(ByRef out As %DynamicArray, ByRef seen, findings As %DynamicArray, sourceRisk As %String, defaultPriority As %String, actionType As %String, slaHours As %Integer) [ Internal ]
{
    If '$ISOBJECT(findings) {
        Quit
    }
    For i=0:1:(findings.%Size()-1) {
        Set one = findings.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }
        Set msg = ..SafeGet(one, "message")
        If msg = "" {
            Continue
        }
        Do ..AddStructuredAction(.out, .seen, actionType, defaultPriority, slaHours, msg, sourceRisk)
    }
}

ClassMethod AddStructuredAction(ByRef out As %DynamicArray, ByRef seen, actionType As %String, priority As %String, slaHours As %Integer, actionText As %String, sourceRisk As %String) [ Internal ]
{
    If actionText = "" {
        Quit
    }
    Set k = actionType _ "|" _ actionText
    If $Get(seen(k)) {
        Quit
    }
    Set seen(k) = 1
    Do out.%Push({
        "actionType": (actionType),
        "priority": (priority),
        "slaHours": (+slaHours),
        "action": (actionText),
        "sourceRisk": (sourceRisk)
    })
}

ClassMethod MedicationMatchesRule(rule As %DynamicObject, normalizedMedication As %String, rxCode As %String = "") As %Boolean [ Internal ]
{
    If '$ISOBJECT(rule) {
        Return 0
    }

    Set ruleMed = ..SafeGet(rule, "med")
    Set ruleRx = ..SafeGet(rule, "rxnormCode")
    Set ruleFamily = ..SafeGet(rule, "medFamily")

    Set medMatch = 0
    If ruleMed '= "" {
        Set medMatch = ..ContainsInsensitive(normalizedMedication, ruleMed)
    }
    If 'medMatch, (ruleRx '= ""), (rxCode '= "") {
        Set medMatch = (rxCode = ruleRx)
    }
    If 'medMatch, (ruleFamily '= "") {
        Set medMatch = ..MedicationHasFamily(normalizedMedication, ruleFamily)
    }

    Return medMatch
}

ClassMethod MedicationHasFamily(normalizedMedication As %String, family As %String) As %Boolean [ Internal ]
{
    Set t = $ZCVT(normalizedMedication, "L")
    Set f = $ZCVT(family, "L")

    If (t = "") || (f = "") {
        Return 0
    }

    If f = "nsaid" {
        If (t [ "ibuprofen") || (t [ "naproxen") || (t [ "diclofenac") || (t [ "indomethacin") || (t [ "ketorolac") || (t [ "celecoxib") || (t [ "meloxicam") {
            Return 1
        }
    }

    If f = "hepatotoxic-risk" {
        If (t [ "methotrexate") || (t [ "valproate") || (t [ "isoniazid") || (t [ "acetaminophen") || (t [ "amiodarone") {
            Return 1
        }
    }

    If f = "diarrhea-malabsorption-risk" {
        If (t [ "orlistat") || (t [ "metformin") || (t [ "acarbose") || (t [ "colchicine") {
            Return 1
        }
    }

    If f = "systemic-corticosteroid" {
        If (t [ "prednisone") || (t [ "prednisolone") || (t [ "methylprednisolone") || (t [ "dexamethasone") {
            Return 1
        }
    }

    If f = "stimulant" {
        If (t [ "methylphenidate") || (t [ "amphetamine") || (t [ "lisdexamfetamine") {
            Return 1
        }
    }

    If f = "ssri-snri" {
        If (t [ "sertraline") || (t [ "fluoxetine") || (t [ "escitalopram") || (t [ "venlafaxine") || (t [ "duloxetine") {
            Return 1
        }
    }

    If f = "opioid" {
        If (t [ "oxycodone") || (t [ "morphine") || (t [ "hydrocodone") || (t [ "codeine") || (t [ "fentanyl") || (t [ "tramadol") {
            Return 1
        }
    }

    If f = "atypical-antipsychotic" {
        If (t [ "olanzapine") || (t [ "quetiapine") || (t [ "risperidone") || (t [ "clozapine") || (t [ "aripiprazole") {
            Return 1
        }
    }

    Return 0
}

ClassMethod BuildConditionIndex(conditionBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set out = []
    If '$ISOBJECT(conditionBundle) {
        Return out
    }

    Set entries = conditionBundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return out
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }

        Set condId = ..SafeGet(r, "id")
        Set codeObj = r.%Get("code")
        Set condText = ..ExtractCodeableText(codeObj)

        Set code = ""
        If $ISOBJECT(codeObj) {
            Set coding = codeObj.%Get("coding")
            If $ISOBJECT(coding) && (coding.%Size()>0) {
                Set first = coding.%Get(0)
                If $ISOBJECT(first) {
                    Set code = ..SafeGet(first, "code")
                }
            }
        }

        Do out.%Push({
            "conditionId": (condId),
            "conditionCode": (code),
            "conditionText": (condText)
        })
    }

    Return out
}

ClassMethod FindConditionHit(condIndex As %DynamicArray, conditionCode As %String = "", conditionKeyword As %String = "") As %DynamicObject [ Internal ]
{
    If '$ISOBJECT(condIndex) || (condIndex.%Size()=0) {
        Return ""
    }

    For i=0:1:(condIndex.%Size()-1) {
        Set one = condIndex.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }

        Set code = ..SafeGet(one, "conditionCode")
        Set text = ..SafeGet(one, "conditionText")

        Set codeMatch = 0
        If conditionCode '= "" {
            Set codeMatch = (code = conditionCode)
        }
        Set textMatch = 0
        If conditionKeyword '= "" {
            Set textMatch = ..ContainsInsensitive(text, conditionKeyword)
        }

        If codeMatch || textMatch {
            Return one
        }
    }

    Return ""
}

/// Detect warnings where medication choice may worsen pre-existing mental health conditions.
ClassMethod DetectMentalHealthWarnings(medList As %DynamicArray, conditionBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }
    If '$ISOBJECT(conditionBundle) {
        Return findings
    }

    Set condIndex = ..BuildConditionIndex(conditionBundle)
    If '$ISOBJECT(condIndex) || (condIndex.%Size()=0) {
        Return findings
    }

    Set rules = ..GetMentalHealthRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }
        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }
            If '..MedicationMatchesRule(rule, key, rxCode) {
                Continue
            }

            Set condHit = ..FindConditionHit(condIndex, ..SafeGet(rule, "conditionCode"), ..SafeGet(rule, "conditionKeyword"))
            If '$ISOBJECT(condHit) {
                Continue
            }

            Set condId = ..SafeGet(condHit, "conditionId")
            Set sig = ..SafeGet(rule, "id") _ "|" _ medId _ "|" _ condId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Set mhCondText = ..SafeGet(condHit, "conditionText")
            Set mhReasoning = "Warning for " _ medName _ " because patient has a diagnosed condition: " _ mhCondText _ "."

            Do findings.%Push({
                "risk": "possible-mental-health-medication-warning",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "condition": (mhCondText),
                "conditionCode": (..SafeGet(condHit, "conditionCode")),
                "conditionResourceId": (condId),
                "reasoning": (mhReasoning),
                "message": (..SafeGet(rule, "message")),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-mental-health-medication-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetMentalHealthRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "mh-steroid-bipolar",
        "mode": "strict",
        "medFamily": "systemic-corticosteroid",
        "conditionKeyword": "bipolar",
        "severity": "high",
        "message": "Systemic corticosteroids can destabilize mood in bipolar spectrum conditions. Plan close psychiatric monitoring.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "mh-stimulant-anxiety",
        "mode": "conservative",
        "medFamily": "stimulant",
        "conditionKeyword": "anxiety",
        "severity": "moderate",
        "message": "Stimulant-class medications may worsen anxiety symptoms in susceptible patients. Reassess dose/agent and monitor symptom burden.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "mh-antidepressant-bipolar",
        "mode": "conservative",
        "medFamily": "ssri-snri",
        "conditionKeyword": "bipolar",
        "severity": "moderate",
        "message": "Antidepressant monotherapy may trigger mood switching in bipolar disorders. Confirm mood-stabilization plan.",
        "reference": "local-curated-rule"
    })

    Return rules
}

/// Detect warnings based on family history risks represented in FamilyMemberHistory.
ClassMethod DetectFamilyHistoryMedicationWarnings(medList As %DynamicArray, familyHistoryBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || (medList.%Size()=0) {
        Return findings
    }
    If '$ISOBJECT(familyHistoryBundle) {
        Return findings
    }

    Set fhIndex = ..BuildFamilyHistoryIndex(familyHistoryBundle)
    If '$ISOBJECT(fhIndex) || (fhIndex.%Size()=0) {
        Return findings
    }

    Set rules = ..GetFamilyHistoryMedicationRules()
    If '$ISOBJECT(rules) || (rules.%Size()=0) {
        Return findings
    }

    Kill seen
    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }
        Set key = ..SafeGet(med, "normalizedKey")
        Set medName = ..SafeGet(med, "name")
        Set medId = ..SafeGet(med, "resourceId")
        Set rxCode = ..SafeGet(med, "rxnormCode")

        For r=0:1:(rules.%Size()-1) {
            Set rule = rules.%Get(r)
            If '$ISOBJECT(rule) {
                Continue
            }
            If '..MedicationMatchesRule(rule, key, rxCode) {
                Continue
            }

            Set fhHit = ..FindFamilyHistoryHit(fhIndex, ..SafeGet(rule, "familyConditionCode"), ..SafeGet(rule, "familyConditionKeyword"))
            If '$ISOBJECT(fhHit) {
                Continue
            }

            Set fhId = ..SafeGet(fhHit, "familyHistoryId")
            Set sig = ..SafeGet(rule, "id") _ "|" _ medId _ "|" _ fhId
            If $Get(seen(sig)) {
                Continue
            }
            Set seen(sig) = 1

            Set fhRelationship = ..SafeGet(fhHit, "relationship")
            Set fhCondText = ..SafeGet(fhHit, "conditionText")
            Set fhReasoning = "Warning for " _ medName _ " because patient's " _ fhRelationship _ " has: " _ fhCondText _ "."

            Do findings.%Push({
                "risk": "possible-family-history-medication-warning",
                "mode": (..SafeGet(rule, "mode")),
                "severity": (..SafeGet(rule, "severity")),
                "medication": (medName),
                "medicationResourceId": (medId),
                "familyHistoryCondition": (fhCondText),
                "familyHistoryConditionCode": (..SafeGet(fhHit, "conditionCode")),
                "familyHistoryResourceId": (fhId),
                "relationship": (fhRelationship),
                "reasoning": (fhReasoning),
                "message": (..SafeGet(rule, "message")),
                "source": {
                    "type": "knowledge-base",
                    "table": "local-family-history-medication-rules-v1",
                    "ruleId": (..SafeGet(rule, "id")),
                    "reference": (..SafeGet(rule, "reference"))
                }
            })
        }
    }

    Return findings
}

ClassMethod GetFamilyHistoryMedicationRules() As %DynamicArray [ Internal ]
{
    Set rules = []

    Do rules.%Push({
        "id": "fh-opioid-substance-use",
        "mode": "conservative",
        "medFamily": "opioid",
        "familyConditionKeyword": "substance",
        "severity": "moderate",
        "message": "Family history of substance use disorder may increase vulnerability to problematic opioid use. Consider enhanced counseling and follow-up.",
        "reference": "local-curated-rule"
    })

    Do rules.%Push({
        "id": "fh-atypical-antipsychotic-diabetes",
        "mode": "conservative",
        "medFamily": "atypical-antipsychotic",
        "familyConditionKeyword": "diabetes",
        "severity": "moderate",
        "message": "Family history of diabetes with atypical antipsychotic therapy suggests elevated metabolic-risk vigilance.",
        "reference": "local-curated-rule"
    })

    Return rules
}

ClassMethod BuildFamilyHistoryIndex(bundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set out = []
    If '$ISOBJECT(bundle) {
        Return out
    }

    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return out
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }
        If $ZCVT(..SafeGet(r, "resourceType"), "L") '= "familymemberhistory" {
            Continue
        }

        Set fhId = ..SafeGet(r, "id")
        Set relationship = ..ExtractCodeableText(r.%Get("relationship"))
        Set condArr = r.%Get("condition")
        If '$ISOBJECT(condArr) {
            Continue
        }

        For j=0:1:(condArr.%Size()-1) {
            Set one = condArr.%Get(j)
            If '$ISOBJECT(one) {
                Continue
            }
            Set cObj = one.%Get("code")
            Set cText = ..ExtractCodeableText(cObj)
            Set cCode = ""
            If $ISOBJECT(cObj) {
                Set coding = cObj.%Get("coding")
                If $ISOBJECT(coding) && (coding.%Size()>0) {
                    Set first = coding.%Get(0)
                    If $ISOBJECT(first) {
                        Set cCode = ..SafeGet(first, "code")
                    }
                }
            }

            Do out.%Push({
                "familyHistoryId": (fhId),
                "relationship": (relationship),
                "conditionCode": (cCode),
                "conditionText": (cText)
            })
        }
    }

    Return out
}

ClassMethod FindFamilyHistoryHit(fhIndex As %DynamicArray, conditionCode As %String = "", conditionKeyword As %String = "") As %DynamicObject [ Internal ]
{
    If '$ISOBJECT(fhIndex) || (fhIndex.%Size()=0) {
        Return ""
    }

    For i=0:1:(fhIndex.%Size()-1) {
        Set one = fhIndex.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }
        Set code = ..SafeGet(one, "conditionCode")
        Set text = ..SafeGet(one, "conditionText")

        Set codeMatch = 0
        If conditionCode '= "" {
            Set codeMatch = (code = conditionCode)
        }
        Set textMatch = 0
        If conditionKeyword '= "" {
            Set textMatch = ..ContainsInsensitive(text, conditionKeyword)
        }

        If codeMatch || textMatch {
            Return one
        }
    }

    Return ""
}

ClassMethod ExtractOccupationProfile(patient As %DynamicObject, observationBundle As %DynamicObject) As %DynamicObject [ Internal ]
{
    Set occupation = ""
    Set source = ""

    If $ISOBJECT(patient) {
        Set ext = patient.%Get("extension")
        If $ISOBJECT(ext) {
            For i=0:1:(ext.%Size()-1) {
                Set one = ext.%Get(i)
                If '$ISOBJECT(one) {
                    Continue
                }

                Set u = $ZCVT(..SafeGet(one, "url"), "L")
                If '(u [ "occupation") {
                    Continue
                }

                Set occupation = ..SafeGet(one, "valueString")
                If occupation = "" {
                    Set occupation = ..ExtractCodeableText(one.%Get("valueCodeableConcept"))
                }
                If occupation '= "" {
                    Set source = "Patient.extension"
                    Quit
                }
            }
        }
    }

    If occupation = "", $ISOBJECT(observationBundle) {
        Set entries = observationBundle.%Get("entry")
        If $ISOBJECT(entries) {
            For i=0:1:(entries.%Size()-1) {
                Set e = entries.%Get(i)
                If '$ISOBJECT(e) {
                    Continue
                }
                Set r = e.%Get("resource")
                If '$ISOBJECT(r) {
                    Continue
                }
                If $ZCVT(..SafeGet(r, "resourceType"), "L") '= "observation" {
                    Continue
                }

                Set codeObj = r.%Get("code")
                Set codeTxt = $ZCVT(..ExtractCodeableText(codeObj), "L")
                Set hasOcc = (codeTxt [ "occupation")

                If 'hasOcc, $ISOBJECT(codeObj) {
                    Set coding = codeObj.%Get("coding")
                    If $ISOBJECT(coding) {
                        For j=0:1:(coding.%Size()-1) {
                            Set c = coding.%Get(j)
                            If '$ISOBJECT(c) {
                                Continue
                            }
                            If ..SafeGet(c, "code") = "11341-5" {
                                Set hasOcc = 1
                                Quit
                            }
                        }
                    }
                }

                If 'hasOcc {
                    Continue
                }

                Set occupation = ..SafeGet(r, "valueString")
                If occupation = "" {
                    Set occupation = ..ExtractCodeableText(r.%Get("valueCodeableConcept"))
                }
                If occupation '= "" {
                    Set source = "Observation.social-history"
                    Quit
                }
            }
        }
    }

    Return {
        "occupation": (occupation),
        "source": (source),
        "isSafetySensitive": (+..IsSafetySensitiveOccupation(occupation))
    }
}

ClassMethod IsSafetySensitiveOccupation(occupation As %String) As %Boolean [ Internal ]
{
    If occupation = "" {
        Return 0
    }
    Set t = $ZCVT(occupation, "L")
    If (t [ "driver") || (t [ "forklift") || (t [ "truck") || (t [ "bus") {
        Return 1
    }
    If (t [ "pilot") || (t [ "operator") || (t [ "machin") || (t [ "crane") {
        Return 1
    }
    Return 0
}

ClassMethod ExtractPatientFactors(patient As %DynamicObject, conditionBundle As %DynamicObject) As %DynamicObject [ Internal ]
{
    Set sex = ""
    Set ageYears = -1
    If $ISOBJECT(patient) {
        Set sex = $ZCVT(..SafeGet(patient, "gender"), "L")
        Set ageYears = ..ComputeAgeYears(..SafeGet(patient, "birthDate"))
    }

    Set pregnant = ..ConditionBundleHasKeyword(conditionBundle, "pregnan")
    If 'pregnant {
        Set pregnant = ..ConditionBundleHasCode(conditionBundle, "77386006")
    }
    Set lactating = ..ConditionBundleHasKeyword(conditionBundle, "breastfeed")
    If 'lactating {
        Set lactating = ..ConditionBundleHasKeyword(conditionBundle, "lactat")
    }

    Return {
        "sex": (sex),
        "ageYears": (ageYears),
        "pregnant": (+pregnant),
        "lactating": (+lactating)
    }
}

ClassMethod ConditionBundleHasKeyword(bundle As %DynamicObject, keyword As %String) As %Boolean [ Internal ]
{
    If '$ISOBJECT(bundle) || (keyword="") {
        Return 0
    }

    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return 0
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }

        Set codeObj = r.%Get("code")
        Set text = ..ExtractCodeableText(codeObj)
        If ..ContainsInsensitive(text, keyword) {
            Return 1
        }
    }

    Return 0
}

ClassMethod ConditionBundleHasCode(bundle As %DynamicObject, code As %String) As %Boolean [ Internal ]
{
    If '$ISOBJECT(bundle) || (code="") {
        Return 0
    }

    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return 0
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }

        Set codeObj = r.%Get("code")
        If '$ISOBJECT(codeObj) {
            Continue
        }
        Set coding = codeObj.%Get("coding")
        If '$ISOBJECT(coding) {
            Continue
        }

        For j=0:1:(coding.%Size()-1) {
            Set one = coding.%Get(j)
            If '$ISOBJECT(one) {
                Continue
            }
            If ..SafeGet(one, "code") = code {
                Return 1
            }
        }
    }

    Return 0
}

ClassMethod ComputeAgeYears(birthDate As %String) As %Integer [ Internal ]
{
    If birthDate = "" {
        Return -1
    }

    Set by = +$Piece(birthDate, "-", 1)
    If by<=0 {
        Return -1
    }
    Set bm = +$Piece(birthDate, "-", 2)
    If bm<=0 {
        Set bm = 1
    }
    Set bd = +$Piece(birthDate, "-", 3)
    If bd<=0 {
        Set bd = 1
    }

    Set today = $Piece($ZDATETIME($HOROLOG, 3, 1), " ", 1)
    Set ty = +$Piece(today, "-", 1)
    Set tm = +$Piece(today, "-", 2)
    Set td = +$Piece(today, "-", 3)
    If ty<=0 {
        Return -1
    }

    Set age = ty - by
    If (tm<bm) || ((tm=bm) && (td<bd)) {
        Set age = age - 1
    }
    If age<0 {
        Set age = -1
    }
    Return age
}

ClassMethod CrossCheckAllergies(medList As %DynamicArray, allergyBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []
    If '$ISOBJECT(medList) || '$ISOBJECT(allergyBundle) {
        Return findings
    }

    Set allergyTerms = []
    Set entries = allergyBundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return findings
    }

    For i=0:1:(entries.%Size()-1) {
        Set e = entries.%Get(i)
        If '$ISOBJECT(e) {
            Continue
        }
        Set r = e.%Get("resource")
        If '$ISOBJECT(r) {
            Continue
        }
        Set term = ..ExtractAllergyName(r)
        If term '= "" {
            Do allergyTerms.%Push({
                "term": (term),
                "allergyId": (..SafeGet(r, "id"))
            })
        }
    }

    If allergyTerms.%Size()=0 {
        Return findings
    }

    For i=0:1:(medList.%Size()-1) {
        Set med = medList.%Get(i)
        If '$ISOBJECT(med) {
            Continue
        }
        Set medName = ..SafeGet(med, "name")
        If medName = "" {
            Continue
        }

        For j=0:1:(allergyTerms.%Size()-1) {
            Set oneAllergy = allergyTerms.%Get(j)
            If '$ISOBJECT(oneAllergy) {
                Continue
            }
            Set term = ..SafeGet(oneAllergy, "term")
            Set allergyId = ..SafeGet(oneAllergy, "allergyId")
            If ..ContainsInsensitive(medName, term) || ..ContainsInsensitive(term, medName) {
                Do findings.%Push({
                    "risk": "possible-allergy-conflict",
                    "medication": (medName),
                    "medicationResourceId": (..SafeGet(med, "resourceId")),
                    "allergy": (term),
                    "allergyResourceId": (allergyId),
                    "source": {
                        "type": "heuristic",
                        "method": "medication-name-overlaps-allergy-term",
                        "resources": "MedicationRequest/MedicationStatement + AllergyIntolerance"
                    },
                    "message": "Medication name appears to overlap a documented allergy. Confirm before prescribing or administering."
                })
            }
        }
    }

    Return findings
}

ClassMethod DetectAdherenceSignals(requestBundle As %DynamicObject, statementBundle As %DynamicObject, observationBundle As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set findings = []

    Set reqCount = ..CountBundleEntries(requestBundle)
    Set stmtCount = ..CountBundleEntries(statementBundle)

    If (reqCount>0) && (stmtCount=0) {
        Do findings.%Push({
            "risk": "possible-adherence-gap",
            "message": "MedicationRequest records exist but no MedicationStatement records were found. Consider adherence and reconciliation follow-up."
        })
    }

    If $ISOBJECT(requestBundle) {
        Set entries = requestBundle.%Get("entry")
        If $ISOBJECT(entries) {
            For i=0:1:(entries.%Size()-1) {
                Set e = entries.%Get(i)
                If '$ISOBJECT(e) {
                    Continue
                }
                Set r = e.%Get("resource")
                If '$ISOBJECT(r) {
                    Continue
                }
                Set st = $ZCVT(..SafeGet(r, "status"), "L")
                Set medName = ..ExtractMedicationName(r)
                If (st = "on-hold") || (st = "stopped") || (st = "cancelled") {
                    Do findings.%Push({
                        "risk": "medication-status-warning",
                        "status": (st),
                        "medication": (medName),
                        "message": "Medication status indicates interruption or discontinuation. Verify current treatment plan and patient understanding."
                    })
                }

                Set authored = ..SafeGet(r, "authoredOn")
                Set ageDays = ..AgeInDays(authored)
                If (st = "active") && (ageDays>180) {
                    Do findings.%Push({
                        "risk": "possible-stale-prescription",
                        "medication": (medName),
                        "medicationResourceId": (..SafeGet(r, "id")),
                        "ageDays": (ageDays),
                        "message": "Active prescription is older than 180 days. Confirm current use, refill status, and regimen relevance."
                    })
                }
            }
        }
    }

    // Lightweight clinical cue: elevated A1c may indicate adherence or regimen gap.
    If $ISOBJECT(observationBundle) {
        Set entries = observationBundle.%Get("entry")
        If $ISOBJECT(entries) {
            For i=0:1:(entries.%Size()-1) {
                Set e = entries.%Get(i)
                If '$ISOBJECT(e) {
                    Continue
                }
                Set r = e.%Get("resource")
                If '$ISOBJECT(r) {
                    Continue
                }
                Set codeText = $ZCVT(..ExtractCodeableText(r.%Get("code")), "L")
                Set vq = r.%Get("valueQuantity")
                If '$ISOBJECT(vq) {
                    Continue
                }
                Set val = +..SafeGet(vq, "value")
                If (codeText [ "a1c") || (codeText [ "hemoglobin a1c") {
                    If val>8 {
                        Do findings.%Push({
                            "risk": "glycemic-control-concern",
                            "value": (val),
                            "message": "Recent A1c is elevated. Review adherence, education needs, and therapy adjustments."
                        })
                    }
                }
            }
        }
    }

    Return findings
}

ClassMethod AgeInDays(dateText As %String) As %Integer [ Internal ]
{
    If dateText = "" {
        Return -1
    }
    Try {
        Set d = $ZDATEH(dateText, 3)
    } Catch ex {
        Return -1
    }
    If d<1 {
        Return -1
    }
    Set today = +$Piece($HOROLOG, ",", 1)
    Quit (today - d)
}

ClassMethod ExtractMedicationName(resource As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(resource) {
        Return ""
    }

    Set c = resource.%Get("medicationCodeableConcept")
    Set name = ..ExtractCodeableText(c)
    If name '= "" {
        Return name
    }

    Set ref = resource.%Get("medicationReference")
    If $ISOBJECT(ref) {
        Set name = ..SafeGet(ref, "display")
        If name '= "" {
            Return name
        }
        Set name = ..SafeGet(ref, "reference")
        If name '= "" {
            Return name
        }
    }

    Return ""
}

ClassMethod ExtractRxNormCode(resource As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(resource) {
        Return ""
    }

    Set c = resource.%Get("medicationCodeableConcept")
    If '$ISOBJECT(c) {
        Return ""
    }
    Set coding = c.%Get("coding")
    If '$ISOBJECT(coding) {
        Return ""
    }
    For i=0:1:(coding.%Size()-1) {
        Set one = coding.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }
        Set sys = $ZCVT(..SafeGet(one, "system"), "L")
        If (sys [ "rxnorm") || (sys [ "nlm.nih.gov") {
            Return ..SafeGet(one, "code")
        }
    }
    Return ""
}

ClassMethod ExtractAllergyName(resource As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(resource) {
        Return ""
    }

    Set name = ..ExtractCodeableText(resource.%Get("code"))
    If name '= "" {
        Return name
    }

    Return ..SafeGet(resource, "substance")
}

ClassMethod ExtractCodeableText(cc As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(cc) {
        Return ""
    }

    Set t = ..SafeGet(cc, "text")
    If t '= "" {
        Return t
    }

    Set coding = cc.%Get("coding")
    If '$ISOBJECT(coding) || (coding.%Size()=0) {
        Return ""
    }

    Set first = coding.%Get(0)
    If '$ISOBJECT(first) {
        Return ""
    }

    Set t = ..SafeGet(first, "display")
    If t '= "" {
        Return t
    }

    Return ..SafeGet(first, "code")
}

ClassMethod NormalizeMedicationKey(name As %String) As %String [ Internal ]
{
    Set t = $ZCVT(name, "L")
    Set t = $Translate(t, ",.()-/", "       ")

    Set out = ""
    For i=1:1:$Length(t, " ") {
        Set tok = $Piece(t, " ", i)
        If tok = "" {
            Continue
        }
        If +tok>0 {
            Continue
        }
        If (tok="mg") || (tok="mcg") || (tok="ml") || (tok="tablet") || (tok="capsule") || (tok="oral") || (tok="solution") {
            Continue
        }
        If out = "" {
            Set out = tok
        } Else {
            Set out = out _ " " _ tok
        }
    }

    Return $Extract(out, 1, 40)
}

ClassMethod ContainsInsensitive(text As %String, needle As %String) As %Boolean [ Internal ]
{
    If (text="") || (needle="") {
        Return 0
    }
    Set t = $ZCVT(text, "L")
    Set n = $ZCVT(needle, "L")
    Quit $Find(t, n)>0
}

ClassMethod CountBundleEntries(bundle As %DynamicObject) As %Integer [ Internal ]
{
    If '$ISOBJECT(bundle) {
        Return 0
    }
    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) {
        Return 0
    }
    Return entries.%Size()
}

ClassMethod SafeGet(obj As %DynamicObject, key As %String) As %String [ Internal ]
{
    If '$ISOBJECT(obj) {
        Return ""
    }
    Try {
        Set val = obj.%Get(key)
    } Catch ex {
        Return ""
    }
    If val = "" {
        Return ""
    }
    Return val
}

ClassMethod GetFHIR(path As %String) As %DynamicObject [ Internal ]
{
    Set baseUrl = ..GetBaseUrl()
    Set fullUrl = baseUrl _ "/" _ path

    Set req = ##class(%Net.HttpRequest).%New()
    Set req.SSLCheckServerIdentity = 0

    Set basicUser = $SYSTEM.Util.GetEnviron("FHIR_BASIC_USER")
    If basicUser = "" {
        Set basicUser = $GET(^||ENV("FHIR_BASIC_USER"))
    }
    Set basicPass = $SYSTEM.Util.GetEnviron("FHIR_BASIC_PASS")
    If basicPass = "" {
        Set basicPass = $GET(^||ENV("FHIR_BASIC_PASS"))
    }
    If (basicUser '= "") && (basicPass '= "") {
        Set req.Username = basicUser
        Set req.Password = basicPass
    } Else {
        Set token = $SYSTEM.Util.GetEnviron("FHIR_BEARER_TOKEN")
        If token = "" {
            Set token = $GET(^||ENV("FHIR_BEARER_TOKEN"))
        }
        If token '= "" {
            Do req.SetHeader("Authorization", "Bearer " _ token)
        }
    }
    Do req.SetHeader("Accept", "application/fhir+json")

    Set sc = req.Get(fullUrl)
    If $$$ISERR(sc) {
        Return {
            "error": "HTTP request failed",
            "status": ($SYSTEM.Status.GetErrorText(sc)),
            "url": (fullUrl)
        }
    }

    Set code = +req.HttpResponse.StatusCode
    Set raw = ..ReadResponseBody(req.HttpResponse.Data)
    If (code<200) || (code>299) {
        Return {
            "error": "FHIR request failed",
            "statusCode": (code),
            "url": (fullUrl),
            "body": (raw)
        }
    }

    Try {
        Return ##class(%DynamicAbstractObject).%FromJSON(raw)
    } Catch ex {
        Return {
            "resourceType": "Binary",
            "contentType": (req.HttpResponse.GetHeader("Content-Type")),
            "data": (raw)
        }
    }
}

ClassMethod GetBaseUrl() As %String [ Internal ]
{
    Set base = $SYSTEM.Util.GetEnviron("FHIR_BASE_URL")
    If base = "" {
        Set base = $GET(^||ENV("FHIR_BASE_URL"))
    }
    If base = "" {
        Set base = "http://localhost:52773/fhir/r4"
    }
    Return $ZSTRIP(base, "<W", "/")
}

ClassMethod ReadResponseBody(stream As %Stream.Object) As %String [ Internal ]
{
    If '$ISOBJECT(stream) {
        Return ""
    }

    Set out = ""
    While 'stream.AtEnd {
        Set out = out _ stream.Read(32000)
    }
    Return out
}

ClassMethod UrlEncode(s As %String) As %String [ Internal ]
{
    Quit $ZCONVERT(s, "O", "URL")
}

ClassMethod ExtractHost(url As %String) As %String [ Internal ]
{
    Set tmp = url
    If $Extract(tmp,1,8)="https://" {
        Set tmp = $Extract(tmp,9,*)
    } ElseIf $Extract(tmp,1,7)="http://" {
        Set tmp = $Extract(tmp,8,*)
    }
    Set hp = $Piece(tmp, "/", 1)
    Quit $Piece(hp, ":", 1)
}

ClassMethod ExtractPort(url As %String) As %Integer [ Internal ]
{
    Set https = ($Extract(url,1,8)="https://")
    Set tmp = url
    If https {
        Set tmp = $Extract(tmp,9,*)
    } ElseIf $Extract(tmp,1,7)="http://" {
        Set tmp = $Extract(tmp,8,*)
    }
    Set hp = $Piece(tmp, "/", 1)
    Set p = +$Piece(hp, ":", 2)
    If p>0 {
        Quit p
    }
    Quit $Select(https:443, 1:80)
}

ClassMethod ExtractLocation(url As %String) As %String [ Internal ]
{
    Set tmp = url
    If $Extract(tmp,1,8)="https://" {
        Set tmp = $Extract(tmp,9,*)
    } ElseIf $Extract(tmp,1,7)="http://" {
        Set tmp = $Extract(tmp,8,*)
    }
    Set path = $Piece(tmp, "/", 2, *)
    Quit "/" _ path
}

}
