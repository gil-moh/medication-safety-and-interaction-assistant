Include (%AI, %occStatus)

/// Example entry points for the Medication Safety and Interaction Assistant MVP.
Class Sample.AI.Examples.MedicationSafetyAssistant Extends %RegisteredObject
{

/// Build and print a medication safety review for a patient.
ClassMethod Demo(patientId As %String, detailMode As %String = "detailed") As %Status
{
    Try {
        Set tool = ##class(Sample.AI.Tools.MedicationSafetyReadOnly).%New()
        Set snapshot = tool.BuildMedicationReviewSnapshot(patientId, 50)

        If $ISOBJECT(snapshot) && (snapshot.%Get("error") '= "") {
            Write !, "Medication safety demo failed: ", snapshot.%Get("error"), !
            Return $$$ERROR($$$GeneralError, snapshot.%Get("error"))
        }

        Do ..WriteNarrative(snapshot, detailMode)
        Return $$$OK
    } Catch ex {
        Write !, "Medication safety demo failed: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

ClassMethod WriteNarrative(snapshot As %DynamicObject, detailMode As %String = "detailed") [ Internal ]
{
    Set patientId = ..SafeGet(snapshot, "patientId")
    Set counts = snapshot.%Get("resourceCounts")
    Set medList = snapshot.%Get("activeMedicationList")
    Set dupes = snapshot.%Get("duplicateTherapyFindings")
    Set interactions = snapshot.%Get("medicationInteractionFindings")
    Set foodInteractions = snapshot.%Get("medicationFoodInteractionFindings")
    Set populationContraindications = snapshot.%Get("medicationPopulationContraindicationFindings")
    Set activityCautions = snapshot.%Get("medicationActivityCautionFindings")
    Set blackBoxWarnings = snapshot.%Get("medicationBlackBoxWarningFindings")
    Set conditionWarnings = snapshot.%Get("medicationConditionWarningFindings")
    Set labWarnings = snapshot.%Get("medicationLabThresholdWarningFindings")
    Set qtWarnings = snapshot.%Get("medicationQTWarningFindings")
    Set anticholinergicWarnings = snapshot.%Get("medicationAnticholinergicBurdenFindings")
    Set mentalHealthWarnings = snapshot.%Get("medicationMentalHealthWarningFindings")
    Set familyHistoryWarnings = snapshot.%Get("medicationFamilyHistoryWarningFindings")
    Set allergies = snapshot.%Get("allergyCrossCheckFindings")
    Set adherence = snapshot.%Get("adherenceSignals")
    Set recommendedActions = snapshot.%Get("recommendedActions")
    Set vectorSearch = snapshot.%Get("vectorSearch")

    Write !, "Example - Medication Safety and Interaction Assistant", !
    Write !, "Patient Overview", !
    Write "- Patient: ", patientId, !
    Write "- Evidence available: medication requests, medication statements, allergies, conditions, and observations.", !

    Write !, "Clinical Snapshot", !
    Set noFindingsCount = 0

    Do ..WriteBulletArray("Black Box Warnings", blackBoxWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteBulletArray("Active Medications", medList, 1, .hasFindings)

    Do ..WriteBulletArray("Duplicate Therapy Findings", dupes, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Medication Interaction Findings", interactions, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Medication-Food Cautions", foodInteractions, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Population Contraindication Cautions", populationContraindications, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Driving / Machinery Cautions", activityCautions, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Drug-Condition Warnings", conditionWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Medication + Lab Threshold Warnings", labWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("QT / Arrhythmia Cautions", qtWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Anticholinergic Burden", anticholinergicWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Mental Health Medication Warnings", mentalHealthWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteStrictConservativeArray("Family History + Medication Warnings", familyHistoryWarnings, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteBulletArray("Allergy Cross-Check Findings", allergies, 0, .hasFindings, 0)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1

    Do ..WriteBulletArray("Adherence / Reconciliation Signals", adherence, 1, .hasFindings)

    If noFindingsCount > 0 {
        Write "- No additional findings in ", noFindingsCount, " other safety categories.", !
    }

    Write !, "Recommended Actions", !
    Do ..WriteActionArray(recommendedActions)

    Write !, "Counseling Summary", !
    Write "- Address any black box warnings first before routine counseling steps.", !
    Write "- Review the medication list for duplicates, medication interactions, medication-food cautions, pregnancy/lactation/age contraindications, driving/heavy-machinery cautions, black box warnings, drug-condition warnings, mental-health warnings, family-history risks, allergy conflicts, or outdated therapy.", !
    Write "- Confirm how the patient is taking each medicine and whether any doses were missed.", !
    Write "- Keep the patient-facing explanation plain and specific to the current regimen.", !

    Write !, "Context-Aware Guidance", !
    If $ISOBJECT(vectorSearch) {
        Do ..WriteBulletArray("Vector Search", vectorSearch)
    }

    If detailMode '= "brief" {
        Write !, "Review Notes", !
        Write "- MedicationRequests: ", ..CountFromCounts(counts, "medicationRequests"), !
        Write "- MedicationStatements: ", ..CountFromCounts(counts, "medicationStatements"), !
        Write "- Allergies: ", ..CountFromCounts(counts, "allergies"), !
        Write "- Conditions: ", ..CountFromCounts(counts, "conditions"), !
        Write "- FamilyHistory: ", ..CountFromCounts(counts, "familyHistory"), !
        Write "- Observations: ", ..CountFromCounts(counts, "observations"), !
    }
}

ClassMethod WriteBulletArray(label As %String, arr As %DynamicObject, showNone As %Boolean = 1, Output hasFindings As %Integer = 0, showLabelWhenEmpty As %Boolean = 1) [ Internal ]
{
    Set hasFindings = 0
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        If showLabelWhenEmpty {
            Write label, !
        }
        If showNone {
            Write "- (none)", !
        }
        Quit
    }
    Write label, !
    For i=0:1:(arr.%Size()-1) {
        Set item = arr.%Get(i)
        If '$ISOBJECT(item) {
            Continue
        }
        Set hasFindings = 1
        Do ..WriteBulletItem(item)
    }
    If ('hasFindings) && showNone {
        Write "- (none)", !
    }
}

ClassMethod WriteBulletItem(item As %DynamicObject) [ Internal ]
{
    Set risk = $ZCVT(..SafeGet(item, "risk"), "L")
    Set reasoning = ..SafeGet(item, "reasoning")
    Set text = ..SafeGet(item, "message")
    If text = "" {
        Set text = ..SafeGet(item, "risk")
    }
    If text = "" {
        Set text = ..SafeGet(item, "name")
    }
    If text = "" {
        Set text = item.%ToJSON()
    }
    If risk = "black-box-warning" {
        Set text = "URGENT: " _ text
    }
    If reasoning '= "" {
        Write "- ", reasoning, !,  "  ", text, !
    } Else {
        Write "- ", text, !
    }
}

/// Write findings array grouped strict warnings first, then conservative extras.
ClassMethod WriteStrictConservativeArray(label As %String, arr As %DynamicObject, showNone As %Boolean = 1, Output hasFindings As %Integer = 0, showLabelWhenEmpty As %Boolean = 1) [ Internal ]
{
    Set hasFindings = 0
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        If showLabelWhenEmpty {
            Write label, !
        }
        If showNone {
            Write "- (none)", !
        }
        Quit
    }
    Write label, !

    Set strictCount = 0
    Set conservativeCount = 0
    For i=0:1:(arr.%Size()-1) {
        Set item = arr.%Get(i)
        If '$ISOBJECT(item) {
            Continue
        }
        Set mode = $ZCVT(..SafeGet(item, "mode"), "L")
        If mode = "strict" {
            Set strictCount = strictCount + 1
        } Else {
            Set conservativeCount = conservativeCount + 1
        }
    }

    If strictCount > 0 {
        Set hasFindings = 1
        Write "  [core / evidence-based]", !
        For i=0:1:(arr.%Size()-1) {
            Set item = arr.%Get(i)
            If '$ISOBJECT(item) {
                Continue
            }
            If $ZCVT(..SafeGet(item, "mode"), "L") '= "strict" {
                Continue
            }
            Do ..WriteBulletItem(item)
        }
    }

    If conservativeCount > 0 {
        Set hasFindings = 1
        Write "  [conservative / context extras]", !
        For i=0:1:(arr.%Size()-1) {
            Set item = arr.%Get(i)
            If '$ISOBJECT(item) {
                Continue
            }
            If $ZCVT(..SafeGet(item, "mode"), "L") = "strict" {
                Continue
            }
            Do ..WriteBulletItem(item)
        }
    }

    If ('hasFindings) && showNone {
        Write "- (none)", !
    }
}

ClassMethod WriteActionArray(arr As %DynamicObject) [ Internal ]
{
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        Write "- (none)", !
        Quit
    }
    For i=0:1:(arr.%Size()-1) {
        Set one = arr.%Get(i)
        If '$ISOBJECT(one) {
            Continue
        }
        Set t = ..SafeGet(one, "actionType")
        Set p = ..SafeGet(one, "priority")
        Set sla = +..SafeGet(one, "slaHours")
        Set a = ..SafeGet(one, "action")
        If a = "" {
            Continue
        }
        If t = "" {
            Set t = "monitor"
        }
        If p = "" {
            Set p = "routine"
        }
        If sla<1 {
            Set sla = 72
        }
        Write "- [", p, " | ", t, " | SLA<=", sla, "h] ", a, !
    }
}

ClassMethod CountFromCounts(counts As %DynamicObject, key As %String) As %String [ Internal ]
{
    If '$ISOBJECT(counts) {
        Return "0"
    }
    Try {
        Set value = counts.%Get(key)
    } Catch ex {
        Return "0"
    }
    Return value
}

ClassMethod SafeGet(obj As %DynamicObject, key As %String) As %String [ Internal ]
{
    If '$ISOBJECT(obj) {
        Return ""
    }
    Try {
        Set value = obj.%Get(key)
    } Catch ex {
        Return ""
    }
    Return value
}

}
