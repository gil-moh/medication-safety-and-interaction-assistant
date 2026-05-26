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

/// Build clinician-facing narrative text directly (no terminal/session scaffolding).
ClassMethod DemoClinician(patientId As %String, detailMode As %String = "detailed") As %String
{
    Try {
        Set tool = ##class(Sample.AI.Tools.MedicationSafetyReadOnly).%New()
        Set snapshot = tool.BuildMedicationReviewSnapshot(patientId, 50)

        If $ISOBJECT(snapshot) && (snapshot.%Get("error") '= "") {
            Return "Medication safety demo failed: " _ snapshot.%Get("error")
        }

        Return ..BuildClinicianNarrative(snapshot, detailMode)
    } Catch ex {
        Return "Medication safety demo failed: " _ ex.DisplayString()
    }
}

ClassMethod BuildClinicianNarrative(snapshot As %DynamicObject, detailMode As %String = "detailed") As %String [ Internal ]
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

    Set out = ""
    Do ..AddLine(.out, "Example - Medication Safety and Interaction Assistant")
    Do ..AddLine(.out)
    Do ..AddLine(.out, "Patient Overview")
    Do ..AddLine(.out, "- Patient: " _ patientId)
    Do ..AddLine(.out, "- Evidence available: medication requests, medication statements, allergies, conditions, and observations.")
    Do ..AddLine(.out)

    Do ..AddLine(.out, "Clinical Snapshot")
    Set noFindingsCount = 0
    Do ..AppendSimpleSection(.out, "Active Medications", medList, .hasFindings)

    Do ..AppendSimpleSection(.out, "Black Box Warnings", blackBoxWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendSimpleSection(.out, "Duplicate Therapy Findings", dupes, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Medication Interaction Findings", interactions, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Medication-Food Cautions", foodInteractions, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Population Contraindication Cautions", populationContraindications, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Driving / Machinery Cautions", activityCautions, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Drug-Condition Warnings", conditionWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Medication + Lab Threshold Warnings", labWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "QT / Arrhythmia Cautions", qtWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Anticholinergic Burden", anticholinergicWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Mental Health Medication Warnings", mentalHealthWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendModeSection(.out, "Family History + Medication Warnings", familyHistoryWarnings, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendSimpleSection(.out, "Allergy Cross-Check Findings", allergies, .hasFindings)
    If 'hasFindings Set noFindingsCount = noFindingsCount + 1
    Do ..AppendSimpleSection(.out, "Adherence / Reconciliation Signals", adherence, .hasFindings)

    If noFindingsCount > 0 {
        Do ..AddLine(.out, "- No additional findings in " _ noFindingsCount _ " other safety categories.")
    }

    Do ..AddLine(.out)
    Do ..AddLine(.out, "Recommended Actions")
    Do ..AppendActionSection(.out, recommendedActions)

    Do ..AddLine(.out)
    Do ..AddLine(.out, "Counseling Summary")
    Do ..AppendCounselingSummary(.out, blackBoxWarnings, dupes, interactions, foodInteractions, populationContraindications, activityCautions, conditionWarnings, labWarnings, qtWarnings, anticholinergicWarnings, mentalHealthWarnings, familyHistoryWarnings, allergies, adherence)

    Do ..AddLine(.out)
    Do ..AddLine(.out, "Context-Aware Guidance")
    Do ..AppendVectorSection(.out, vectorSearch)

    If detailMode '= "brief" {
        Do ..AddLine(.out)
        Do ..AddLine(.out, "Review Notes")
        Do ..AddLine(.out, "- MedicationRequests: " _ ..CountFromCounts(counts, "medicationRequests"))
        Do ..AddLine(.out, "- MedicationStatements: " _ ..CountFromCounts(counts, "medicationStatements"))
        Do ..AddLine(.out, "- Allergies: " _ ..CountFromCounts(counts, "allergies"))
        Do ..AddLine(.out, "- Conditions: " _ ..CountFromCounts(counts, "conditions"))
        Do ..AddLine(.out, "- FamilyHistory: " _ ..CountFromCounts(counts, "familyHistory"))
        Do ..AddLine(.out, "- Observations: " _ ..CountFromCounts(counts, "observations"))
    }

    Return out
}

ClassMethod AddLine(ByRef out As %String, line As %String = "") [ Internal ]
{
    Set out = out _ line _ $C(10)
}

ClassMethod AppendSimpleSection(ByRef out As %String, label As %String, arr As %DynamicObject, Output hasFindings As %Integer = 0) [ Internal ]
{
    Set hasFindings = 0
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        Quit
    }
    Do ..AddLine(.out, label)
    For i=0:1:(arr.%Size()-1) {
        Set item = arr.%Get(i)
        If '$ISOBJECT(item) {
            Continue
        }
        Set hasFindings = 1
        Do ..AppendBulletFromItem(.out, item)
    }
}

ClassMethod AppendModeSection(ByRef out As %String, label As %String, arr As %DynamicObject, Output hasFindings As %Integer = 0) [ Internal ]
{
    Set hasFindings = 0
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        Quit
    }

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

    If (strictCount + conservativeCount)=0 {
        Quit
    }

    Set hasFindings = 1
    Do ..AddLine(.out, label)

    If strictCount>0 {
        Do ..AddLine(.out, "  [core / evidence-based]")
        For i=0:1:(arr.%Size()-1) {
            Set item = arr.%Get(i)
            If '$ISOBJECT(item) {
                Continue
            }
            If $ZCVT(..SafeGet(item, "mode"), "L") '= "strict" {
                Continue
            }
            Do ..AppendBulletFromItem(.out, item)
        }
    }

    If conservativeCount>0 {
        Do ..AddLine(.out, "  [conservative / context extras]")
        For i=0:1:(arr.%Size()-1) {
            Set item = arr.%Get(i)
            If '$ISOBJECT(item) {
                Continue
            }
            If $ZCVT(..SafeGet(item, "mode"), "L") = "strict" {
                Continue
            }
            Do ..AppendBulletFromItem(.out, item)
        }
    }
}

ClassMethod AppendBulletFromItem(ByRef out As %String, item As %DynamicObject) [ Internal ]
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
        Do ..AddLine(.out, "- " _ reasoning)
        Do ..AddLine(.out, "  " _ text)
    } Else {
        Do ..AddLine(.out, "- " _ text)
    }
}

ClassMethod AppendActionSection(ByRef out As %String, arr As %DynamicObject) [ Internal ]
{
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        Do ..AddLine(.out, "- (none)")
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
        Do ..AddLine(.out, "- [" _ p _ " | " _ t _ " | SLA<=" _ sla _ "h] " _ a)
    }
}

ClassMethod AppendVectorSection(ByRef out As %String, vectorSearch As %DynamicObject) [ Internal ]
{
    Set snippets = ""
    If $ISOBJECT(vectorSearch) {
        Set snippets = vectorSearch.%Get("snippets")
    }
    If '$ISOBJECT(snippets) || (snippets.%Size()=0) {
        Do ..AddLine(.out, "- No additional contextual guidance available.")
        Quit
    }
    Do ..AddLine(.out, "Vector Search")
    For i=0:1:(snippets.%Size()-1) {
        Set s = snippets.%Get(i)
        If '$ISOBJECT(s) {
            Continue
        }
        Set txt = ..SafeGet(s, "text")
        If txt = "" {
            Continue
        }
        Do ..AddLine(.out, "- " _ txt)
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
    Do ..WriteCounselingSummary(blackBoxWarnings, dupes, interactions, foodInteractions, populationContraindications, activityCautions, conditionWarnings, labWarnings, qtWarnings, anticholinergicWarnings, mentalHealthWarnings, familyHistoryWarnings, allergies, adherence)

    Write !, "Context-Aware Guidance", !
    Do ..WriteVectorSearch(vectorSearch)

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

ClassMethod WriteVectorSearch(vectorSearch As %DynamicObject) [ Internal ]
{
    Write "Vector Search", !
    If '$ISOBJECT(vectorSearch) {
        Write "- (none)", !
        Quit
    }

    Set snippets = vectorSearch.%Get("snippets")
    If '$ISOBJECT(snippets) || (snippets.%Size()=0) {
        Write "- No additional contextual guidance available.", !
        Quit
    }

    For i=0:1:(snippets.%Size()-1) {
        Set s = snippets.%Get(i)
        If '$ISOBJECT(s) {
            Continue
        }
        Set topic = ..SafeGet(s, "topic")
        Set txt = ..SafeGet(s, "text")
        Set src = ..SafeGet(s, "source")
        If topic = "" {
            Set topic = "guidance"
        }
        If txt = "" {
            Continue
        }
        Write "- ", txt, !
    }
}

ClassMethod BuildCounselingBullets(blackBoxWarnings As %DynamicObject, dupes As %DynamicObject, interactions As %DynamicObject, foodInteractions As %DynamicObject, populationContraindications As %DynamicObject, activityCautions As %DynamicObject, conditionWarnings As %DynamicObject, labWarnings As %DynamicObject, qtWarnings As %DynamicObject, anticholinergicWarnings As %DynamicObject, mentalHealthWarnings As %DynamicObject, familyHistoryWarnings As %DynamicObject, allergies As %DynamicObject, adherence As %DynamicObject) As %DynamicArray [ Internal ]
{
    Set bullets = []

    Do ..AddCounselingBulletIfFindings(.bullets, blackBoxWarnings, "Prioritize immediate mitigation of black-box risks identified above.")
    Do ..AddCounselingBulletIfFindings(.bullets, dupes, "Reconcile possible duplicate therapy and confirm the intended regimen.")
    Do ..AddCounselingBulletIfFindings(.bullets, interactions, "Review flagged drug-drug interactions and ensure an explicit monitoring plan.")
    Do ..AddCounselingBulletIfFindings(.bullets, foodInteractions, "Provide targeted diet or substance counseling for the flagged medication-food risks.")
    Do ..AddCounselingBulletIfFindings(.bullets, populationContraindications, "Reassess age, pregnancy, or lactation contraindication risks before continuing therapy.")
    Do ..AddCounselingBulletIfFindings(.bullets, activityCautions, "Counsel on driving or machinery restrictions tied to the current therapy.")
    Do ..AddCounselingBulletIfFindings(.bullets, conditionWarnings, "Validate medication safety against active conditions and adjust treatment if needed.")
    Do ..AddCounselingBulletIfFindings(.bullets, labWarnings, "Order or verify follow-up labs for medication-related threshold warnings.")
    Do ..AddCounselingBulletIfFindings(.bullets, qtWarnings, "Review QT or arrhythmia risk and consider ECG or electrolyte reassessment when indicated.")
    Do ..AddCounselingBulletIfFindings(.bullets, anticholinergicWarnings, "Reduce anticholinergic burden where possible and monitor cognition and fall risk.")
    Do ..AddCounselingBulletIfFindings(.bullets, mentalHealthWarnings, "Screen for mental-health adverse effects linked to the flagged medications.")
    Do ..AddCounselingBulletIfFindings(.bullets, familyHistoryWarnings, "Discuss family-history-related vulnerability and set tighter follow-up expectations.")
    Do ..AddCounselingBulletIfFindings(.bullets, allergies, "Resolve any medication-allergy conflicts before administration.")
    Do ..AddCounselingBulletIfFindings(.bullets, adherence, "Perform medication reconciliation with patient-reported use and missed doses.")

    If bullets.%Size()=0 {
        Do bullets.%Push("No additional counseling priorities were identified from current data.")
    }

    Return bullets
}

ClassMethod AddCounselingBulletIfFindings(ByRef bullets As %DynamicArray, findings As %DynamicObject, text As %String) [ Internal ]
{
    If (text="") || ('$ISOBJECT(bullets)) {
        Quit
    }
    If ..HasItems(findings) {
        Do bullets.%Push(text)
    }
}

ClassMethod WriteCounselingSummary(blackBoxWarnings As %DynamicObject, dupes As %DynamicObject, interactions As %DynamicObject, foodInteractions As %DynamicObject, populationContraindications As %DynamicObject, activityCautions As %DynamicObject, conditionWarnings As %DynamicObject, labWarnings As %DynamicObject, qtWarnings As %DynamicObject, anticholinergicWarnings As %DynamicObject, mentalHealthWarnings As %DynamicObject, familyHistoryWarnings As %DynamicObject, allergies As %DynamicObject, adherence As %DynamicObject) [ Internal ]
{
    Set bullets = ..BuildCounselingBullets(blackBoxWarnings, dupes, interactions, foodInteractions, populationContraindications, activityCautions, conditionWarnings, labWarnings, qtWarnings, anticholinergicWarnings, mentalHealthWarnings, familyHistoryWarnings, allergies, adherence)
    If '$ISOBJECT(bullets) || (bullets.%Size()=0) {
        Write "- No additional counseling priorities were identified from current data.", !
        Quit
    }

    For i=0:1:(bullets.%Size()-1) {
        Set one = bullets.%Get(i)
        If one = "" {
            Continue
        }
        Write "- ", one, !
    }
}

ClassMethod AppendCounselingSummary(ByRef out As %String, blackBoxWarnings As %DynamicObject, dupes As %DynamicObject, interactions As %DynamicObject, foodInteractions As %DynamicObject, populationContraindications As %DynamicObject, activityCautions As %DynamicObject, conditionWarnings As %DynamicObject, labWarnings As %DynamicObject, qtWarnings As %DynamicObject, anticholinergicWarnings As %DynamicObject, mentalHealthWarnings As %DynamicObject, familyHistoryWarnings As %DynamicObject, allergies As %DynamicObject, adherence As %DynamicObject) [ Internal ]
{
    Set bullets = ..BuildCounselingBullets(blackBoxWarnings, dupes, interactions, foodInteractions, populationContraindications, activityCautions, conditionWarnings, labWarnings, qtWarnings, anticholinergicWarnings, mentalHealthWarnings, familyHistoryWarnings, allergies, adherence)
    If '$ISOBJECT(bullets) || (bullets.%Size()=0) {
        Do ..AddLine(.out, "- No additional counseling priorities were identified from current data.")
        Quit
    }

    For i=0:1:(bullets.%Size()-1) {
        Set one = bullets.%Get(i)
        If one = "" {
            Continue
        }
        Do ..AddLine(.out, "- " _ one)
    }
}

ClassMethod HasItems(arr As %DynamicObject) As %Boolean [ Internal ]
{
    If '$ISOBJECT(arr) {
        Return 0
    }
    Return (arr.%Size()>0)
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
