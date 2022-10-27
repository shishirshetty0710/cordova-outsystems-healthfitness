
import OSHealthFitnessLib
import HealthKit

@objc(OSHealthFitness)
class OSHealthFitness: CordovaImplementation {
    var plugin: HealthFitnessPlugin?
    var callbackId:String=""
    
    override func pluginInitialize() {
        plugin = HealthFitnessPlugin()
    }
    
    @objc(requestPermissions:)
    func requestPermissions(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        
        let customPermissions = command.arguments[0] as? String ?? ""
        let allVariables = command.arguments[1] as? String ?? ""
        let fitnessVariables = command.arguments[2] as? String ?? ""
        let healthVariables = command.arguments[3] as? String ?? ""
        let profileVariables = command.arguments[4] as? String ?? ""
        let summaryVariables = command.arguments[5] as? String ?? ""
        let variable = VariableStruct(allVariables: allVariables, fitnessVariables: fitnessVariables, healthVariables: healthVariables, profileVariables: profileVariables, summaryVariables: summaryVariables)
        
        self.plugin?.requestPermissions(customPermissions:customPermissions, variable: variable) { [weak self] authorized, error in
            guard let self = self else { return }
            
            self.sendResult(result: "", error: !authorized ? error : nil, callBackID: self.callbackId)
        }
    }
    
    @objc(writeData:)
    func writeData(command: CDVInvokedUrlCommand) {
        callbackId = command.callbackId
        
        guard let variable = command.arguments[0] as? String else {
            return self.sendResult(result: "", error:HealthKitErrors.badParameterType as NSError, callBackID: self.callbackId)
        }
        
        guard let value = command.arguments[1] as? Double else {
            return  self.sendResult(result: "", error:HealthKitErrors.badParameterType as NSError, callBackID: self.callbackId)
        }
        
        plugin?.writeData(variable: variable, value: value) { success,error in
            if let err = error {
                self.sendResult(result: "", error:err, callBackID: self.callbackId)
            }
            if success {
                self.sendResult(result: "", error: nil, callBackID: self.callbackId)
            }
        }
    }
    
    @objc(updateBackgroundJob:)
    func updateBackgroundJob(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        
        let queryParameters = command.arguments[0] as? String ?? ""
        if let parameters = self.parseUpdateParameters(parameters: queryParameters) {
            self.plugin?.updateBackgroundJob(
                id: parameters.id,
                notificationFrequency: (parameters.notificationFrequency, parameters.notificationFrequencyGrouping),
                condition: parameters.condition,
                value: parameters.value,
                notificationText: (parameters.notificationHeader, parameters.notificationBody),
                isActive: parameters.isActive
            ) { [weak self] success, error in
                guard let self = self else { return }
                
                self.sendResult(result: "", error: !success ? error : nil, callBackID: self.callbackId)
            }
        }
    }
    
    private func parseUpdateParameters(parameters: String) -> BackgroundJobParameters? {
        let data = parameters.data(using: .utf8)!
        if let jsonData = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as? Dictionary<String,Any> {
            
            // I'm doing this mess because Outsystems
            // seams to be sending the parameters as strings.
            let id = Int64(jsonData["Id"] as? String ?? "")
            let notificationFrequency = jsonData["NotificationFrequency"] as? String
            let notificationFrequencyGrouping = jsonData["NotificationFrequencyGrouping"] as? Int
            let condition = jsonData["Condition"] as? String
            let value = jsonData["Value"] as? Double
            let notificationHeader = jsonData["NotificationHeader"] as? String
            let notificationBody = jsonData["NotificationBody"] as? String
            var isActive: Bool? = nil
            let activeString = jsonData["IsActive"] as? String ?? ""
            if activeString != "" {
                isActive = activeString.lowercased() == "true"
            }
            
            return BackgroundJobParameters(id: id,
                                           variable: nil,
                                           timeUnit: nil,
                                           timeUnitGrouping: nil,
                                           notificationFrequency: notificationFrequency,
                                           notificationFrequencyGrouping: notificationFrequencyGrouping,
                                           jobFrequency: nil,
                                           condition: condition,
                                           value: value,
                                           notificationHeader: notificationHeader,
                                           notificationBody: notificationBody,
                                           isActive: isActive)
        }
        return nil
    }
    
    @objc(getLastRecord:)
    func getLastRecord(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        let variable = command.arguments[0] as? String ?? ""
        
        self.plugin?.advancedQuery(
            variable: variable,
            date: (Date.distantPast, Date()),
            timeUnit: "",
            operationType: "MOST_RECENT",
            mostRecent: true,
            onlyFilledBlocks: false,
            timeUnitLength: 1
        ) { [weak self] success, result, error in
            guard let self = self else { return }
            
            if success {
                self.sendResult(result: result, error: nil, callBackID: self.callbackId)
            } else {
                self.sendResult(result: nil, error: error, callBackID: self.callbackId)
            }
        }
    }
    
    @objc(deleteBackgroundJob:)
    func deleteBackgroundJob(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        let id = command.arguments[0] as? String ?? ""
        
        self.plugin?.deleteBackgroundJobs(id: id) { [weak self] error in
            guard let self = self else { return }
            
            self.sendResult(result: error == nil ? "" : nil, error: error, callBackID: self.callbackId)
        }
    }
    
    @objc(listBackgroundJobs:)
    func listBackgroundJobs(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        
        let result = self.plugin?.listBackgroundJobs()
        self.sendResult(result: result, error: nil, callBackID: self.callbackId)
    }
    
    @objc(setBackgroundJob:)
    func setBackgroundJob(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        
        let queryParameters = command.arguments[0] as? String ?? ""
        if let params = queryParameters.decode() as BackgroundJobParameters? {
            
            let variable = params.variable ?? ""
            let timeUnitGrouping = params.timeUnitGrouping ?? 0
            let condition = params.condition ?? ""
            let timeUnit = params.timeUnit ?? ""
            let jobFrequency = params.jobFrequency ?? ""
            let notificationFrequency = params.notificationFrequency ?? ""
            let notificationFrequencyGrouping = params.notificationFrequencyGrouping ?? 0
            let value = params.value ?? 0
            let notificationHeader = params.notificationHeader ?? ""
            let notificationBody = params.notificationBody ?? ""
            
            self.plugin?.setBackgroundJob(
                variable: variable,
                timeUnit: (timeUnit,  timeUnitGrouping),
                notificationFrequency: (notificationFrequency, notificationFrequencyGrouping),
                jobFrequency: jobFrequency,
                condition: condition,
                value: value,
                notificationText: (notificationHeader, notificationBody)
            ) { [weak self] success, result, error in
                guard let self = self else { return }
                
                if success {
                    self.sendResult(result: result, error: nil, callBackID: self.callbackId)
                } else {
                    self.sendResult(result: nil, error: error, callBackID: self.callbackId)
                }
            }
        }
    }
    
    @objc(getData:)
    func getData(command: CDVInvokedUrlCommand) {
        self.callbackId = command.callbackId
        
        let queryParameters = command.arguments[0] as? String ?? ""
        if let params = queryParameters.decode() as QueryParameters? {
            
            let variable = params.variable ?? ""
            let startDate = params.startDate ?? ""
            let endDate = params.endDate ?? ""
            let timeUnit = params.timeUnit ?? ""
            let operationType = params.operationType ?? ""
            let timeUnitLength = params.timeUnitLength ?? 1
            let onlyFilledBlocks = params.advancedQueryReturnType == AdvancedQueryReturnTypeEnum.removeEmptyDataBlocks.rawValue
            let resultType = AdvancedQueryResultType.get(with: params.advancedQueryResultType ?? "")
            
            self.plugin?.advancedQuery(
                variable: variable,
                date: (Date(startDate), Date(endDate)),
                timeUnit: timeUnit,
                operationType: operationType,
                mostRecent: false,
                onlyFilledBlocks: onlyFilledBlocks,
                resultType: resultType,
                timeUnitLength: timeUnitLength
            ) { [weak self] success, result, error in
                guard let self = self else { return }
                
                if success {
                    self.sendResult(result: result, error: nil, callBackID: self.callbackId)
                } else {
                    self.sendResult(result: nil, error: error, callBackID: self.callbackId)
                }
            }
        }
    }
    
    func convertHKWorkoutActivityTypeToString(which:HKWorkoutActivityType) -> String {
      switch(which) {

      case .archery:  return "archery";

      case .badminton:  return "badminton";

      case .baseball:  return "baseball";

      case .barre:  return "barre";

      case .basketball:  return "basketball";

      case .cycling:  return "biking";

      case .handCycling:  return "biking.hand";

      case .bowling:  return "bowling";

      case .boxing: return "boxing";

        case .cricket:  return "cricket";

        case .cooldown: return "cooldown";

        case .coreTraining:  return "core_training";

        case .crossTraining:  return "crossfit";

        case .curling:  return "curling";

        case .dance:  return "dancing";

        case .cardioDance:  return "dancing";

        case .socialDance: return "dancing.social";

        case .discSports: return "disc_sports";

        case .elliptical:  return "elliptical";

        case .fencing:  return "fencing";

        case .fishing:  return "fishing";

        case .fitnessGaming: return "fitness_gaming";

        case .flexibility:  return "flexibility";

        case .americanFootball:  return "football.american";

        case .australianFootball:  return "football.australian";

        case .soccer:  return "football.soccer";

        case .functionalStrengthTraining:  return "functional_strength";

        case .golf:  return "golf";

        case .gymnastics:  return "gymnastics";

        case .handball:  return "handball";

        case .hiking:  return "hiking";

        case .hockey:  return "hockey";

        case .equestrianSports:  return "horseback_riding";

        case .hunting:  return "hunting";

        case .highIntensityIntervalTraining:  return "interval_training.high_intensity";

        case .jumpRope: return "jump_rope";

        case .kickboxing:  return "kickboxing";

        case .martialArts:  return "martial_arts";

        case .lacrosse:  return "lacrosse";

        case .mindAndBody:  return "meditation";

        case .mixedCardio:  return "mixed_metabolic_cardio";

        case .other:  return "other";

        case .paddleSports:  return "paddle_sports";

        case .play:  return "play";

        case .pickleball: return "pickleball";

        case .pilates:  return "pilates";

        case .preparationAndRecovery:  return "preparation_and_recovery";

        case .racquetball:  return "racquetball";

        case .climbing:  return "rock_climbing";

        case .rowing:  return "rowing";

        case .rugby:  return "rugby";

        case .running:  return "running";

        case .sailing:  return "sailing";

        case .skatingSports:  return "skating";

        case .downhillSkiing:  return "skiing.downhill";

        case .snowSports:  return "snow_sports";

        case .crossCountrySkiing:  return "skiing.cross_country";

        case .snowboarding:  return "snowboarding";

        case .softball:  return "softball";

        case .squash:  return "squash";

        case .stairClimbing:  return "stair_climbing";

      case .stepTraining: return "stair_climbing.machine";

      case .stairs:  return "stairs";

      case .traditionalStrengthTraining:  return "strength_training";

      case .surfingSports:  return "surfing";

      case .swimming:  return "swimming";

      case .tableTennis:  return "table_tennis";

      case .taiChi: return "tai_chi";

      case .tennis:  return "tennis";

      case .trackAndField:  return "track_and_field";

      case .volleyball:  return "volleyball";

      case .walking:  return "walking";

      case .waterFitness:  return "water_fitness";

      case .waterPolo:  return "water_polo";

      case .waterSports:  return "water_sports";

      case .wheelchairWalkPace:  return "wheelchair.walkpace";

      case .wheelchairRunPace:  return "wheelchair.runpace";

      case .wrestling:  return "wrestling";

      case .yoga:  return "yoga";

      default: return "other";

      }
    }
    
    func stringFromDate(date:Date) ->String {
        let formatter:DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        return formatter.string(from: date)
    }
    
    @objc(findWorkouts:)
    func findWorkouts(command: CDVInvokedUrlCommand){
        let args:NSDictionary = command.arguments[0] as! NSDictionary;
        let startDateNumber:NSNumber? = args["startDate"] as? NSNumber
        let endDateNumber:NSNumber? = args["endDate"] as? NSNumber
        let startDate = Date.init(timeIntervalSince1970: TimeInterval(startDateNumber!.intValue))
        let endDate = Date.init(timeIntervalSince1970: TimeInterval(endDateNumber!.intValue))
        
        let ascending = (args["ascending"] != nil && args["ascending"] as! Bool)
        
        findWorkouts(callbackId: command.callbackId, startDate: startDate, endDate: endDate, ascending: ascending)
    }
    
    @objc(findWorkouts:withStartDate:withEndDate:ascending:)
    func findWorkouts(callbackId:String, startDate:Date, endDate:Date, ascending:Bool){
        
        let workoutPredicate:NSPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictStartDate);
        
        let endDateSort = NSSortDescriptor.init(key: HKSampleSortIdentifierEndDate, ascending: ascending)
        // TODO if a specific workouttype was passed, use that
        //  if (false) {
        //    workoutPredicate = [HKQuery predicateForWorkoutsWithWorkoutActivityType:HKWorkoutActivityTypeCycling];
        //  }
        let types:Set<HKWorkoutType> = [HKWorkoutType.workoutType()]
        HKHealthStore().requestAuthorization(toShare: nil, read: types) { [weak self] success, olderror in
            guard let self = self else {return}
            if(!success){
                DispatchQueue.main.sync {
                    let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:olderror?.localizedDescription)
                    self.commandDelegate.send(result,callbackId: callbackId)
                }
            }else{
                let query = HKSampleQuery.init(sampleType: HKWorkoutType.workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil){
                    sampleQuery, samples,innerError in
                    if((innerError) != nil){
                        DispatchQueue.main.sync {
                            let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:innerError?.localizedDescription)
                            self.commandDelegate.send(result,callbackId: callbackId)
                        }
                    }else{
                        guard let results: [HKWorkout] = samples as? [HKWorkout] else { return }

                        var finalResults:[Dictionary<String,Any>] = []
                        
                        for workout:HKWorkout in results {
                            let workoutActivity = self.convertHKWorkoutActivityTypeToString(which: workout.workoutActivityType)

                            // iOS 9 moves the source property to a collection of revisions
                            let source = workout.sourceRevision.source

                            // TODO: use a float value, or switch to metric
                            let miles = workout.totalDistance?.doubleValue(for: .meterUnit(with: .none))
                            let milesString = String(format: "%ld",miles!)

                            // Parse totalEnergyBurned in kilocalories
                            let cals = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                            let calories = String(format: "%d", cals!)
                            
                            let entry = [
                                "duration": workout.duration,
                                "startDate": self.stringFromDate(date: workout.startDate),
                                "endDate": self.stringFromDate(date: workout.endDate),
                                "distance": milesString,
                                "energy": calories,
                                "sourceBundleId": source.bundleIdentifier,
                                "sourceName": source.name,
                                "activityType": workoutActivity,
                                "UUID": workout.uuid.uuidString
                            ] as Dictionary
                            
                            finalResults.append(entry)
                        }
                        DispatchQueue.main.sync {
                            let result = CDVPluginResult(status:CDVCommandStatus_OK, messageAs:finalResults)
                            self.commandDelegate.send(result,callbackId: callbackId)
                        }
                    }
                };
                HKHealthStore().execute(query)
            }
        }
    }
    
    /**
     * Get sample type by name
     *
     * @param elem  *NSString
     * @return      *HKSampleType
     */
    func getHKSampleType(elem:NSString) -> HKSampleType? {

        var type:HKSampleType?
        
        type = HKObjectType.quantityType(forIdentifier: elem as HKQuantityTypeIdentifier)
        
        if (type != nil) {
            return type
        }

        type = HKObjectType.categoryType(forIdentifier: elem as HKCategoryTypeIdentifier)
        if (type != nil) {
            return type
        }

        type = HKObjectType.correlationType(forIdentifier: elem as HKCorrelationTypeIdentifier)
        if (type != nil) {
            return type
        }
        
        if elem == "workoutType"{
            return HKObjectType.workoutType()
        }

        // leave this here for if/when apple adds other sample types
        return type

    }
    
    @objc(querySampleType:)
    func querySampleType(command: CDVInvokedUrlCommand){
        let args:NSDictionary = command.arguments[0] as! NSDictionary;
        let startDateNumber:NSNumber? = args["startDate"] as? NSNumber
        let endDateNumber:NSNumber? = args["endDate"] as? NSNumber
        let startDate = Date.init(timeIntervalSince1970: TimeInterval(startDateNumber!.intValue))
        let endDate = Date.init(timeIntervalSince1970: TimeInterval(endDateNumber!.intValue))
        
        let sampleTypeString:String = args["sampleType"] as! String
        var unitString:String? = args["unit"] as? String
        
        let ascending = (args["ascending"] != nil && args["ascending"] as! Bool)

        let typeTemp = self.getHKSampleType(elem: sampleTypeString as NSString)
        if typeTemp == nil {
            let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:"sampleType was invalid")
            self.commandDelegate.send(result,callbackId: command.callbackId)
            return
        }
        let type = typeTemp!
        var unit:HKUnit? = nil
        if unitString != nil {
            if unitString == "mmol/L" {
                // @see https://stackoverflow.com/a/30196642/1214598
                unit = HKUnit.moleUnit(with: HKMetricPrefix.milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter())
            } else {
                // issue 51
                // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
                if unitString == "percent" {
                    unitString = "%"
                }
                unit = HKUnit.init(from: unitString!)
            }
        }
        // TODO check that unit is compatible with sampleType if sample type of HKQuantityType
        let predicate:NSPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictStartDate)
        
        let requestTypes:Set<HKObjectType> = Set.init(arrayLiteral: type)
        HKHealthStore().requestAuthorization(toShare: nil, read: requestTypes) {[weak self] success, error in
            guard let self = self else {return}
            if success {
                let endDateSort = NSSortDescriptor.init(key: HKSampleSortIdentifierEndDate, ascending: ascending)
                let query = HKSampleQuery.init(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [endDateSort]) { sampleQuery, results, innerError in
                    
                    if (innerError != nil) {
                        DispatchQueue.main.sync {
                            let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:innerError!.localizedDescription)
                            self.commandDelegate.send(result,callbackId: command.callbackId)
                        }
                    } else {
                        
                        var finalResults:[Dictionary<String,Any>] = []

                        for sample:HKSample in results! {

                            let startSample = sample.startDate
                            let endSample = sample.endDate
                            var entry:Dictionary<String,Any> = Dictionary()
                            //NSMutableDictionary *entry = [NSMutableDictionary dictionary];

                            // common indices
                            entry[ "startDate"] = self.stringFromDate(date: startSample)
                            entry[ "endDate"] = self.stringFromDate(date: endSample)
                            entry[ "UUID"] = sample.uuid.uuidString

                            entry[ "sourceName"] = sample.sourceRevision.source.name
                            entry[ "sourceBundleId"] = sample.sourceRevision.source.bundleIdentifier

                            if sample.metadata == nil || JSONSerialization.isValidJSONObject(sample.metadata!) {
                                entry[ "metadata"] = []
                            } else {
                                entry[ "metadata"] = sample.metadata
                            }

                            // case-specific indices
                            if sample is HKCategorySample {
                                let csample = sample as! HKCategorySample
                                entry[ "value"] = csample.value
                                entry[ "categoryType.identifier"] = csample.categoryType.identifier
                                entry[ "categoryType.description"] = csample.categoryType.description
                            }else if sample is HKCorrelation{
                                let correlation = sample as! HKCorrelation
                                entry[ "correlationType"] = correlation.correlationType.identifier
                                
                            }else if sample is HKQuantitySample {
                                let qsample = sample as! HKQuantitySample
                                entry[ "quantity"] = qsample.quantity.doubleValue(for: unit!)

                            } else if sample is HKWorkout {
                                
                                let wsample = sample as! HKWorkout
                                entry[ "duration"] = wsample.duration

                            }
                            
                            finalResults.append(entry)
                        }
                        DispatchQueue.main.sync {
                            let result = CDVPluginResult(status:CDVCommandStatus_OK, messageAs:finalResults)
                            self.commandDelegate.send(result,callbackId: command.callbackId)
                        }
                    }
                }
                HKHealthStore().execute(query)
            }else {
                DispatchQueue.main.sync {
                    let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:error!.localizedDescription)
                    self.commandDelegate.send(result,callbackId: command.callbackId)
                }
            }
        }
    }
    
    @objc(queryCorrelationType:)
    func queryCorrelationType(command: CDVInvokedUrlCommand){
        let args:Dictionary = command.arguments[0] as! Dictionary<String, Any>;
        let startDateNumber:NSNumber = args["startDate"] as! NSNumber
        let endDateNumber:NSNumber = args["endDate"] as! NSNumber
        let startDate = Date.init(timeIntervalSinceReferenceDate: TimeInterval(startDateNumber.doubleValue))
        let endDate = Date.init(timeIntervalSinceReferenceDate: TimeInterval(endDateNumber.doubleValue))
        
        let correlationTypeString:String = args["correlationType"] as! String
        let unitsString:[String?] = args["units"] as! [String?]
        

        let typeTemp:HKCorrelationType? = self.getHKSampleType(elem: correlationTypeString as NSString) as? HKCorrelationType
        if typeTemp == nil {
            let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:"sampleType was invalid")
            self.commandDelegate.send(result,callbackId: command.callbackId)
            return
        }
        let type = typeTemp!
        
        var units:[HKUnit?] = []
        for unitString:String? in unitsString {
            let unit = (unitString != nil) ? HKUnit.init(from: unitString!) : nil
            units.append(unit)
        }

        // TODO check that unit is compatible with sampleType if sample type of HKQuantityType
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictStartDate)

        let query = HKCorrelationQuery.init(type: type, predicate: predicate, samplePredicates: nil, completion: {[weak self] correlationQuery, correlations, error in
            guard let self = self else {return}
            if ((error) != nil) {
                DispatchQueue.main.sync {
                    let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:error!.localizedDescription)
                    self.commandDelegate.send(result,callbackId: command.callbackId)
                }
            } else {
                var finalResult:[Dictionary<String,Any>] = []
                for sample:HKSample in correlations! {
                    let startSample = sample.startDate
                    let endSample = sample.endDate
                    
                    var entry:Dictionary<String,Any> = Dictionary()
                    
                    entry[ "startDate"] = self.stringFromDate(date: startSample)
                    entry[ "endDate"] = self.stringFromDate(date: endSample)
                    
                    entry[ "UUID"] = sample.uuid.uuidString
                    entry[ "sourceName"] = sample.sourceRevision.source.name
                    entry[ "sourceBundleId"] = sample.sourceRevision.source.bundleIdentifier

                    if sample.metadata == nil || JSONSerialization.isValidJSONObject(sample.metadata!) {
                        entry[ "metadata"] = []
                    } else {
                        entry[ "metadata"] = sample.metadata
                    }
                    
                    if sample is HKCategorySample {
                        let csample = sample as! HKCategorySample
                        entry[ "value"] = csample.value
                        entry[ "categoryType.identifier"] = csample.categoryType.identifier
                        entry[ "categoryType.description"] = csample.categoryType.description
                    }else if sample is HKCorrelation{
                        let correlation = sample as! HKCorrelation
                        entry[ "correlationType"] = correlation.correlationType.identifier

                        let samples:NSDictionary = NSDictionary.init()
                        guard let correlationObjs:Set<HKQuantitySample> = correlation.objects as? Set<HKQuantitySample> else { return }
                        for quantitySample:HKQuantitySample in correlationObjs {
                            for (index,unit) in units.enumerated() {
                                let unitS = unitsString[index]
                                if quantitySample.quantity.is(compatibleWith: unit!) {
                                    entry[ "startDate"] = self.stringFromDate(date:quantitySample.startDate)
                                    entry[ "endDate"] = self.stringFromDate(date:quantitySample.endDate)
                                    entry[ "sampleType"] = quantitySample.sampleType.identifier
                                    entry[ "value"] = quantitySample.quantity.doubleValue(for: unit!)
                                    entry[ "unit"] = unitS
                                    entry[ "metadata"] = (quantitySample.metadata != nil && JSONSerialization.isValidJSONObject(quantitySample.metadata!)) ? quantitySample.metadata : []
                                    entry[ "UUID"] = quantitySample.uuid.uuidString
                                    break;
                                }
                            }
                        }
                        entry[ "samples"] = samples
                        
                    }else if sample is HKQuantitySample {
                        let qsample = sample as! HKQuantitySample
                        for unit:HKUnit? in units {
                            if qsample.quantity.is(compatibleWith: unit!) {
                                let quantity = qsample.quantity.doubleValue(for: unit!)
                                entry[ "quantity"] = String.init(format:"%f",quantity)
                                break;
                            }
                        }
                    }
                    finalResult.append(entry)
                }
                
                DispatchQueue.main.sync {
                    let result = CDVPluginResult(status:CDVCommandStatus_OK, messageAs:finalResult)
                    self.commandDelegate.send(result,callbackId: command.callbackId)
                }
            }
        });
        HKHealthStore().execute(query)
    }
}
