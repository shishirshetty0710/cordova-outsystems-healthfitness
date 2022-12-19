
import OSHealthFitnessLib
import HealthKit

private protocol PlatformProtocol {
    func sendResult(result: String?, error: NSError?, callBackID:String)
}

@objc(OSHealthFitness)
class OSHealthFitness: CDVPlugin {
    var plugin: HealthFitnessPlugin?
    var callbackIds:NSMutableDictionary?
    var bgTask : UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    var sharedSession:URLSession?
    
    override func pluginInitialize() {
        plugin = HealthFitnessPlugin()
        callbackIds = NSMutableDictionary()
        
        sharedSession = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    @objc(requestPermissions:)
    func requestPermissions(command: CDVInvokedUrlCommand) {
        self.callbackIds!["requestPermissions"] = command.callbackId
        
        let customPermissions = command.arguments[0] as? String ?? ""
        let allVariables = command.arguments[1] as? String ?? ""
        let fitnessVariables = command.arguments[2] as? String ?? ""
        let healthVariables = command.arguments[3] as? String ?? ""
        let profileVariables = command.arguments[4] as? String ?? ""
        let summaryVariables = command.arguments[5] as? String ?? ""
        let variable = VariableStruct(allVariables: allVariables, fitnessVariables: fitnessVariables, healthVariables: healthVariables, profileVariables: profileVariables, summaryVariables: summaryVariables)
        
        self.plugin?.requestPermissions(customPermissions:customPermissions, variable: variable) { [weak self] authorized, error in
            guard let self = self else { return }
            
            self.sendResult(result: "", error: !authorized ? error : nil, callBackID: self.callbackIds!["requestPermissions"] as! String)
        }
    }
    
    @objc(writeData:)
    func writeData(command: CDVInvokedUrlCommand) {
        self.callbackIds!["writeData"] = command.callbackId
        
        guard let variable = command.arguments[0] as? String else {
            return self.sendResult(result: "", error:HealthKitErrors.badParameterType as NSError, callBackID: self.callbackIds!["writeData"] as! String)
        }
        
        guard let value = command.arguments[1] as? Double else {
            return  self.sendResult(result: "", error:HealthKitErrors.badParameterType as NSError, callBackID: self.callbackIds!["writeData"] as! String)
        }
        
        plugin?.writeData(variable: variable, value: value) { success,error in
            if let err = error {
                self.sendResult(result: "", error:err, callBackID: self.callbackIds!["writeData"] as! String)
            }
            if success {
                self.sendResult(result: "", error: nil, callBackID: self.callbackIds!["writeData"] as! String)
            }
        }
    }
    
    @objc(updateBackgroundJob:)
    func updateBackgroundJob(command: CDVInvokedUrlCommand) {
        self.callbackIds!["updateBackgroundJob"] = command.callbackId
        
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
                
                self.sendResult(result: "", error: !success ? error : nil, callBackID: self.callbackIds!["updateBackgroundJob"] as! String)
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
        self.callbackIds!["getLastRecord"] = command.callbackId
        let variable = command.arguments[0] as? String ?? ""
        
        self.plugin?.advancedQuery(
            variable: variable,
            date: (Date.distantPast, Date()),
            timeUnit: "",
            operationType: "MOST_RECENT",
            mostRecent: true,
            onlyFilledBlocks: true,
            resultType: .rawDataType,
            timeUnitLength: 1
        ) { [weak self] success, result, error in
            guard let self = self else { return }
            
            if success {
                self.sendResult(result: result, error: nil, callBackID: self.callbackIds!["getLastRecord"] as! String)
            } else {
                self.sendResult(result: nil, error: error, callBackID: self.callbackIds!["getLastRecord"] as! String)
            }
        }
    }
    
    @objc(deleteBackgroundJob:)
    func deleteBackgroundJob(command: CDVInvokedUrlCommand) {
        self.callbackIds!["deleteBackgroundJob"] = command.callbackId
        let id = command.arguments[0] as? String ?? ""
        
        self.plugin?.deleteBackgroundJobs(id: id) { [weak self] error in
            guard let self = self else { return }
            
            self.sendResult(result: error == nil ? "" : nil, error: error, callBackID: self.callbackIds!["deleteBackgroundJob"] as! String)
        }
    }
    
    @objc(listBackgroundJobs:)
    func listBackgroundJobs(command: CDVInvokedUrlCommand) {
        self.callbackIds!["listBackgroundJobs"] = command.callbackId
        
        let result = self.plugin?.listBackgroundJobs()
        self.sendResult(result: result, error: nil, callBackID: self.callbackIds!["listBackgroundJobs"] as! String)
    }
    
    @objc(setBackgroundJob:)
    func setBackgroundJob(command: CDVInvokedUrlCommand) {
        self.callbackIds!["setBackgroundJob"] = command.callbackId
        
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
                    self.sendResult(result: result, error: nil, callBackID: self.callbackIds!["setBackgroundJob"] as! String)
                } else {
                    self.sendResult(result: nil, error: error, callBackID: self.callbackIds!["setBackgroundJob"] as! String)
                }
            }
        }
    }
    
    @objc(getData:)
    func getData(command: CDVInvokedUrlCommand) {
        self.callbackIds!["getData"] = command.callbackId
        
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
                    self.sendResult(result: result, error: nil, callBackID: self.callbackIds!["getData"] as! String)
                } else {
                    self.sendResult(result: nil, error: error, callBackID: self.callbackIds!["getData"] as! String)
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
    
    func stringFromDate(dateComp:DateComponents) ->String {
        let date = dateComp.date
        let formatter:DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: date!)
    }
    
    func stringFromDate(date:Date) ->String {
        let formatter:DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        return formatter.string(from: date)
    }
    
    
    /**
     * Read gender data
     *
     * @param command *CDVInvokedUrlCommand
     */
    func readGender(command:CDVInvokedUrlCommand) {
        self.callbackIds!["readGender"] = command.callbackId
        let genderType = HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex)
        HKHealthStore().requestAuthorization(toShare: nil, read: Set<HKCharacteristicType>([genderType!])) { [weak self] success, error in
            guard let self = self else {return}
            if(success){
                do{
                    let sex = try HKHealthStore().biologicalSex()
                    var gender:String;
                    switch (sex.biologicalSex) {
                        case HKBiologicalSex.male:
                            gender = "male";
                            break;
                        case HKBiologicalSex.female:
                            gender = "female";
                            break;
                        case HKBiologicalSex.other:
                            gender = "other";
                            break;
                        default:
                            gender = "unknown";
                    }
                    let result = CDVPluginResult(status: CDVCommandStatus.ok, messageAs: gender)
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["readGender"] as! String)
                }catch(let innerError){
                    let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:innerError.localizedDescription)
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["readGender"] as! String)
                }
            }
        }
    }
    
    /**
     * Read date of birth data
     *
     * @param command *CDVInvokedUrlCommand
     */
    func readDateOfBirth(command:CDVInvokedUrlCommand){
        self.callbackIds!["readDateOfBirth"] = command.callbackId
        let birthdayType = HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth)
        HKHealthStore().requestAuthorization(toShare: nil, read: Set<HKCharacteristicType>([birthdayType!])) { [weak self] success, error in
            guard let self = self else {return}
            if(success){
                do{
                    let dateOfBirth = try HKHealthStore().dateOfBirthComponents()
                    let result = CDVPluginResult(status: CDVCommandStatus.ok, messageAs: self.stringFromDate(dateComp: dateOfBirth))
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["readDateOfBirth"] as! String)
                }catch(let innerError){
                    let result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:innerError.localizedDescription)
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["readDateOfBirth"] as! String)
                }
            }
        }
    }
    
    func sendPostRequest(jsonItems:Data, task:Dictionary<String,AnyHashable>){
        let defaults = UserDefaults.standard
        
        let url = defaults.string(forKey: "url")
        
        if url == nil {
            return;
        }
        var urlRequest = URLRequest(url: URL(string: url!)!)
        
        urlRequest.httpMethod = "POST"
        
        let headers = defaults.array(forKey: "headers")
        
        for header in headers! {
            let headerDic = header as! [String:Any]
            urlRequest.setValue(headerDic["Value"] as! String, forHTTPHeaderField: headerDic["Key"] as! String)
        }
        
        let urltask = sharedSession?.uploadTask(with: urlRequest, from: jsonItems, completionHandler: { data, response, error in
            if (error != nil) {
                return;
            }
            var tasks = UserDefaults.standard.array(forKey: "BackgroundTasks")
            let index = tasks!.firstIndex { innerTask in
                let innerTaskTemp = innerTask as! Dictionary<String,AnyHashable>
                return task == innerTaskTemp
            }
            tasks!.remove(at: index!)
            UserDefaults.standard.setValue(tasks, forKey: "BackgroundTasks")
        })

        urltask?.resume()
    }
    
    @objc(findWorkouts:)
    func findWorkouts(command: CDVInvokedUrlCommand){
        self.callbackIds!["findWorkouts"] = command.callbackId
        let args:NSDictionary = command.arguments[0] as! NSDictionary;
        let startDateNumber:NSNumber? = args["startDate"] as? NSNumber
        let endDateNumber:NSNumber? = args["endDate"] as? NSNumber
        let startDate = Date.init(timeIntervalSince1970: TimeInterval(startDateNumber!.intValue))
        let endDate = Date.init(timeIntervalSince1970: TimeInterval(endDateNumber!.intValue))
        
        let isTask:Bool? = args["task"] as? Bool
        var task = Dictionary<String,AnyHashable>()
        if isTask != nil {
            var tasks = UserDefaults.standard.array(forKey: "BackgroundTasks")
            task["function"] = 0
            task["startDate"] = startDate
            task["endDate"] = endDate
            if tasks == nil {
                tasks = Array()
            }
            tasks!.append(task);
            UserDefaults.standard.setValue(tasks, forKey: "BackgroundTasks")
            UserDefaults.standard.synchronize()
            
            self.commandDelegate.send(CDVPluginResult(status: CDVCommandStatus.ok, messageAs: []), callbackId: self.callbackIds!["findWorkouts"] as! String)
        }
        DispatchQueue.main.async {
            self.findWorkouts(startDate: startDate, endDate: endDate) { workoutList,error in
                if isTask != nil && error == nil {
                    do{
                        let json = try JSONSerialization.data(withJSONObject: workoutList!)
                        self.sendPostRequest(jsonItems:json,task: task);
                    }catch _{
                        
                    }
                }else{
                    var result:CDVPluginResult
                    if(error == nil){
                        result = CDVPluginResult(status: CDVCommandStatus.ok, messageAs: workoutList)
                    }else{
                        result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:error)
                    }
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["findWorkouts"] as! String)
                }
            }
        }
    }

    @objc(querySampleType:)
    func querySampleType(command: CDVInvokedUrlCommand){
        self.callbackIds!["querySampleType"] = command.callbackId
        let args:NSDictionary = command.arguments[0] as! NSDictionary;
        let startDateNumber:NSNumber? = args["startDate"] as? NSNumber
        let endDateNumber:NSNumber? = args["endDate"] as? NSNumber
        let startDate = Date.init(timeIntervalSince1970: TimeInterval(startDateNumber!.intValue))
        let endDate = Date.init(timeIntervalSince1970: TimeInterval(endDateNumber!.intValue))
        
        let sampleTypeString:String = args["sampleType"] as! String
        let unitString:String? = args["unit"] as? String
        
        let isTask:Bool? = args["task"] as? Bool
        var task = Dictionary<String,AnyHashable>()
        if isTask != nil {
            var tasks = UserDefaults.standard.array(forKey: "BackgroundTasks")
            task["function"] = 1
            task["startDate"] = startDate
            task["endDate"] = endDate
            task["units"] = unitString
            task["type"] = sampleTypeString
            if tasks == nil {
                tasks = Array()
            }
            tasks!.append(task);
            UserDefaults.standard.setValue(tasks, forKey: "BackgroundTasks")
            UserDefaults.standard.synchronize()
            
            self.commandDelegate.send(CDVPluginResult(status: CDVCommandStatus.ok, messageAs: []), callbackId: self.callbackIds!["querySampleType"] as! String)
        }
        DispatchQueue.main.async {
            self.querySampleType(sampleType: sampleTypeString, units: unitString, startDate: startDate, endDate: endDate) {samplesList, error in
                if isTask != nil && error == nil {
                    do{
                        let json = try JSONSerialization.data(withJSONObject: samplesList!)
                        let json_str = String(decoding: json, as: UTF8.self)
                        json_str = "{" + "type:" + sampleTypeString + "," + json_str + "}"
                        json = Data(json_str.utf8)
                        self.sendPostRequest(jsonItems:json,task: task);
                    }catch _{
                        
                    }
                }else{
                    var result:CDVPluginResult
                    if(error == nil){
                        result = CDVPluginResult(status: CDVCommandStatus.ok, messageAs: samplesList)
                    }else{
                        result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:error)
                    }
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["querySampleType"] as! String)
                }
            }
        }
    }
    
    @objc(queryCorrelationType:)
    func queryCorrelationType(command: CDVInvokedUrlCommand){
        self.callbackIds!["queryCorrelationType"] = command.callbackId
        let args:Dictionary = command.arguments[0] as! Dictionary<String, Any>;
        let startDateNumber:NSNumber = args["startDate"] as! NSNumber
        let endDateNumber:NSNumber = args["endDate"] as! NSNumber
        let startDate = Date.init(timeIntervalSince1970: TimeInterval(startDateNumber.doubleValue))
        let endDate = Date.init(timeIntervalSince1970: TimeInterval(endDateNumber.doubleValue))
        
        let correlationTypeString:String = args["correlationType"] as! String
        let unitsString:[String] = args["units"] as! [String]
        
        let isTask:Bool? = args["task"] as? Bool
        var task = Dictionary<String,AnyHashable>()
        if isTask != nil {
            var tasks = UserDefaults.standard.array(forKey: "BackgroundTasks")
            task["function"] = 2
            task["startDate"] = startDate
            task["endDate"] = endDate
            task["units"] = unitsString
            task["type"] = correlationTypeString
            if tasks == nil {
                tasks = Array()
            }
            tasks!.append(task);
            UserDefaults.standard.setValue(tasks, forKey: "BackgroundTasks")
            UserDefaults.standard.synchronize()
            
            self.commandDelegate.send(CDVPluginResult(status: CDVCommandStatus.ok, messageAs: []), callbackId: self.callbackIds!["queryCorrelationType"] as! String)
        }
        DispatchQueue.main.async {
            self.queryCorrelationType(correlationTypeString: correlationTypeString, units: unitsString[0], startDate: startDate, endDate: endDate) {samplesList, error in
                if isTask != nil && error == nil {
                    do{
                        let json = try JSONSerialization.data(withJSONObject: samplesList!)
                        let json_str = String(decoding: json, as: UTF8.self)
                        json_str = "{" + "type:" + correlationTypeString + "," + json_str + "}"
                        json = Data(json_str.utf8)
                        self.sendPostRequest(jsonItems:json,task: task);
                    }catch _{
                        
                    }
                }else{
                    var result:CDVPluginResult
                    if(error == nil){
                        result = CDVPluginResult(status: CDVCommandStatus.ok, messageAs: samplesList)
                    }else{
                        result = CDVPluginResult(status:CDVCommandStatus_ERROR, messageAs:error)
                    }
                    self.commandDelegate.send(result,callbackId: self.callbackIds!["queryCorrelationType"] as! String)
                }
            }
        }
        
    }
    
    @objc(findWorkouts:withEndDate:callbackFunction:)
    func findWorkouts(startDate:Date, endDate:Date, callbackFunction:@escaping(([Dictionary<String,Any>]?,String?) -> Void)){
        
        let workoutPredicate:NSPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate);
        
        let types:Set<HKWorkoutType> = [HKWorkoutType.workoutType()]
        HKHealthStore().requestAuthorization(toShare: nil, read: types) { [weak self] success, olderror in
            guard let self = self else {return}
            if(!success){
                DispatchQueue.main.sync {
                    callbackFunction(nil, olderror?.localizedDescription)
                }
            }else{
                let query = HKSampleQuery.init(sampleType: HKWorkoutType.workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil){
                    sampleQuery, samples,innerError in
                    if((innerError) != nil){
                        DispatchQueue.main.sync {
                            callbackFunction(nil, innerError?.localizedDescription)
                        }
                    }else{
                        guard let results: [HKWorkout] = samples as? [HKWorkout] else { return }

                        var finalResults:[Dictionary<String,Any>] = []
                        
                        for workout:HKWorkout in results {
                            let workoutActivity = self.convertHKWorkoutActivityTypeToString(which: workout.workoutActivityType)

                            // iOS 9 moves the source property to a collection of revisions
                            let source = workout.sourceRevision.source

                            // TODO: use a float value, or switch to metric
                            var miles = workout.totalDistance?.doubleValue(for: .meterUnit(with: .none))
                            if miles == nil {
                                miles = 0.0
                            }
                            miles = round(miles!*100.0)/100.0

                            // Parse totalEnergyBurned in kilocalories
                            var calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                            if calories == nil {
                                calories = 0.0
                            }
                            calories = round(calories!*100.0)/100.0
                            
                            let formatter = DateComponentsFormatter()
                            let entry = [
                                "duration": formatter.string(from: workout.duration)!,
                                "startDate": self.stringFromDate(date: workout.startDate),
                                "endDate": self.stringFromDate(date: workout.endDate),
                                "distance": miles!,
                                "energy": calories!,
                                "Source":[
                                    "OS": "\(workout.sourceRevision.operatingSystemVersion.majorVersion).\(workout.sourceRevision.operatingSystemVersion.minorVersion).\(workout.sourceRevision.operatingSystemVersion.patchVersion)",
                                    "Device": workout.sourceRevision.productType,
                                    "BundleID": workout.sourceRevision.source.bundleIdentifier,
                                    "Name": workout.sourceRevision.source.name
                                ],
                                "activityType": workoutActivity,
                            ] as Dictionary<String,Any>
                            
                            finalResults.append(entry)
                        }
                        DispatchQueue.main.sync {
                            callbackFunction(finalResults, nil)
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
    func getHKSampleType(elem:NSString) -> (HKSampleType?,HKCorrelationType?) {

        var type:HKSampleType?
        var correlationtype:HKCorrelationType?
        
        type = HKObjectType.quantityType(forIdentifier: elem as HKQuantityTypeIdentifier)
        
        if (type != nil) {
            return (type,nil)
        }

        type = HKObjectType.categoryType(forIdentifier: elem as HKCategoryTypeIdentifier)
        if (type != nil) {
            return (type,nil)
        }

        correlationtype = HKObjectType.correlationType(forIdentifier: elem as HKCorrelationTypeIdentifier)
        if (correlationtype != nil) {
            return (nil,correlationtype)
        }
        
        if elem == "workoutType"{
            return (HKObjectType.workoutType(),nil)
        }

        // leave this here for if/when apple adds other sample types
        return (nil,nil)

    }
    
    @objc(querySampleType:inUnits:withStartDate:withEndDate:callbackFunction:)
    func querySampleType(sampleType:String, units:String?, startDate:Date, endDate:Date, callbackFunction:@escaping(([Dictionary<String,Any>]?,String?) -> Void)){
        
        let typeTemp = self.getHKSampleType(elem: sampleType as NSString)
        if typeTemp.0 == nil {
            callbackFunction(nil, "sampleType was invalid")
            return
        }
        let type = typeTemp.0!
        var unit:HKUnit? = nil
        if units != nil {
            if units == "mmol/L" {
                // @see https://stackoverflow.com/a/30196642/1214598
                unit = HKUnit.moleUnit(with: HKMetricPrefix.milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter())
            } else if units == "m/s"{
                unit = HKUnit.meter().unitDivided(by: HKUnit.second())
            }else {
                // issue 51
                // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
                if units == "percent" {
                    unit = HKUnit.init(from: "%")
                }else{
                    unit = HKUnit.init(from: units!)
                }
            }
        }
        
        // TODO check that unit is compatible with sampleType if sample type of HKQuantityType
        let predicate:NSPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        
        let requestTypes:Set<HKObjectType> = Set.init(arrayLiteral: type)
        HKHealthStore().requestAuthorization(toShare: nil, read: requestTypes) {[weak self] success, error in
            guard let self = self else {return}
            if success {
                let endDateSort = NSSortDescriptor.init(key: HKSampleSortIdentifierEndDate, ascending: false)
                let query = HKSampleQuery.init(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [endDateSort]) { sampleQuery, results, innerError in
                    
                    if (innerError != nil) {
                            callbackFunction(nil, innerError?.localizedDescription)
                    } else {
                        
                        var finalResults:[Dictionary<String,Any>] = []

                        for sample:HKSample in results! {

                            //NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                            var entry = [
                                "startDate": self.stringFromDate(date: sample.startDate),
                                "endDate": self.stringFromDate(date: sample.endDate),
                                "unit": units!,
                                "Source":[
                                    "OS": "\(sample.sourceRevision.operatingSystemVersion.majorVersion).\(sample.sourceRevision.operatingSystemVersion.minorVersion).\(sample.sourceRevision.operatingSystemVersion.patchVersion)",
                                    "Device": sample.sourceRevision.productType,
                                    "BundleID": sample.sourceRevision.source.bundleIdentifier,
                                    "Name": sample.sourceRevision.source.name
                                ]
                            ] as Dictionary
                            
                            // case-specific indices
                            if sample is HKCategorySample {
                                let csample = sample as! HKCategorySample
                                entry["value"] = csample.value
                            }else if sample is HKCorrelation{
                                let correlation = sample as! HKCorrelation
                                entry["value"] = correlation.correlationType.identifier
                                
                            }else if sample is HKQuantitySample {
                                let qsample = sample as! HKQuantitySample
                                var quantity = qsample.quantity.doubleValue(for: unit!)
                                quantity = round(quantity*100.0)/100.0
                                entry["value"] = quantity

                            } else if sample is HKWorkout {
                                let wsample = sample as! HKWorkout
                                let formatter = DateComponentsFormatter()
                                entry["value"] = formatter.string(from: wsample.duration)!
                            }
                            
                            finalResults.append(entry)
                        }
                        callbackFunction(finalResults, nil)
                    }
                }
                HKHealthStore().execute(query)
            }else {
                callbackFunction(nil, error?.localizedDescription)
            }
        }
    }
    
    @objc(queryCorrelationType:withUnits:withStartDate:withEndDate:callbackFunction:)
    func queryCorrelationType(correlationTypeString:String, units:String, startDate:Date, endDate:Date, callbackFunction:@escaping(([Dictionary<String,Any>]?,String?) -> Void)){
        
        let typeTemp = self.getHKSampleType(elem: correlationTypeString as NSString)
        if typeTemp.1 == nil {
            callbackFunction(nil, "sampleType was invalid")
            return
        }
        let type = typeTemp.1!
        
        let unit = (units != nil) ? HKUnit.init(from: units) : nil

        // TODO check that unit is compatible with sampleType if sample type of HKQuantityType
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        
        var requestTypes:Set<HKObjectType>
        if correlationTypeString == "HKCorrelationTypeIdentifierBloodPressure" {
            requestTypes = Set.init(arrayLiteral: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!)
        }else{
            requestTypes = Set.init(arrayLiteral: HKObjectType.quantityType(forIdentifier: .dietaryIron)!)
        }
        HKHealthStore().requestAuthorization(toShare: nil, read: requestTypes) {[weak self] success, error in
            guard let self = self else {return}
            let query = HKCorrelationQuery.init(type: type, predicate: predicate, samplePredicates: nil, completion: {[weak self] correlationQuery, correlations, error in
                guard let self = self else {return}
                if ((error) != nil) {
                    callbackFunction(nil,error!.localizedDescription)
                } else {
                    var finalResult:[Dictionary<String,Any>] = []
                    for corSample:HKSample in correlations! {
                        
                        var entry = [
                            "startDate": self.stringFromDate(date: corSample.startDate),
                            "endDate": self.stringFromDate(date: corSample.endDate),
                            "unit" : "mmHg",
                            "Source":[
                                "OS": "\(corSample.sourceRevision.operatingSystemVersion.majorVersion).\(corSample.sourceRevision.operatingSystemVersion.minorVersion).\(corSample.sourceRevision.operatingSystemVersion.patchVersion)",
                                "Device": corSample.sourceRevision.productType,
                                "BundleID": corSample.sourceRevision.source.bundleIdentifier,
                                "Name": corSample.sourceRevision.source.name
                            ]
                        ] as Dictionary
                        
                          if corSample is HKCorrelation{
                            let correlation = corSample as! HKCorrelation

                            var sample:Dictionary<String,Any> = Dictionary()
                            guard let correlationObjs:Set<HKQuantitySample> = correlation.objects as? Set<HKQuantitySample> else { return }
                            for quantitySample:HKQuantitySample in correlationObjs {
                                var quantity = quantitySample.quantity.doubleValue(for: unit!)
                                quantity = round(quantity*100)/100
                                if quantitySample.sampleType.identifier == "HKQuantityTypeIdentifierBloodPressureSystolic"  {
                                    sample["systolic"] = quantity
                                }else{
                                    sample["diastolic"] = quantity
                                }
                            }
                            entry["value"] = sample
                            
                        }else if corSample is HKQuantitySample {
                            let qsample = corSample as! HKQuantitySample
                            if qsample.quantity.is(compatibleWith: unit!) {
                                var quantity = qsample.quantity.doubleValue(for: unit!)
                                quantity = round(quantity*100.0)/100.0
                                entry["value"] = String.init(format:"%f",quantity)
                            }
                        }
                        finalResult.append(entry)
                    }
                    callbackFunction(finalResult,nil)
                }
            });
            HKHealthStore().execute(query)
        }
    }
    
    @objc(getDeviceInfo:)
    func getDeviceInfo(command: CDVInvokedUrlCommand) {
        let deviceProperties = self.deviceProperties()

        let result = CDVPluginResult(status:CDVCommandStatus_OK, messageAs:deviceProperties)
        self.commandDelegate.send(result,callbackId: command.callbackId)
    }
    
    func isVirtual() ->Bool
    {
        #if TARGET_OS_SIMULATOR
            return true;
        #elseif TARGET_IPHONE_SIMULATOR
            return true;
        #else
            return false;
        #endif
    }

    
    func isiOSAppOnMac() ->Bool
    {
        #if __IPHONE_14_0
        if  #available(iOS 14.0, *) {
            return NSProcessInfo.processInfo.isiOSAppOnMac
        }
        #endif

        return false;
    }
    
    func uniqueAppInstanceIdentifier(device:UIDevice) -> String
    {
        let userDefaults = UserDefaults.standard
        
        // Check user defaults first to maintain backwards compaitibility with previous versions
        // which didn't user identifierForVendor
        var app_uuid = userDefaults.string(forKey: "CDVUUID")
        
        if app_uuid == nil{
            if UIDevice.responds(to: Selector("identifierForVendor")) {
                app_uuid = device.identifierForVendor!.uuidString
            }else{
                let uuid = CFUUIDCreate(nil)
                let app_uuid_temp = CFUUIDCreateString(nil, uuid) as NSString?
                app_uuid = app_uuid_temp as String?
            }
            userDefaults.setValue(app_uuid, forKey: "CDVUUID")
            userDefaults.synchronize()
        }
        
        return app_uuid!;
    }
    
    func getCDV_VERSION()->String{
        return String(format: "%d.%d.%d", (CORDOVA_VERSION_MIN_REQUIRED / 10000),
                      (CORDOVA_VERSION_MIN_REQUIRED % 10000) / 100,
                      (CORDOVA_VERSION_MIN_REQUIRED % 10000) % 100)
    }


    
    func deviceProperties()-> Dictionary<String, Any>{
        let device = UIDevice.current
        let userDefaults = UserDefaults.standard;
        
        let completedHDU = userDefaults.bool(forKey: "HDUCompleted")
        let historicalDataUpload:Dictionary<String,Any>
        if completedHDU {
            historicalDataUpload = [
                "completed":true,
                "date": userDefaults.string(forKey: "HDUDate")!
            ]
        }else{
            historicalDataUpload = [
                "completed":false
            ]
        }
        
        return[
            "manufacturer": "Apple",
            "model": device.model,
            "platform": "iOS",
            "uuid": device.identifierForVendor!.uuidString,
            "cordova": getCDV_VERSION(),
            "version": Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            "historicalDataUpload":historicalDataUpload
        ]
    }
    
    @objc(setConfigurations:)
    func setConfigurations(command: CDVInvokedUrlCommand){
        let userDefaults = UserDefaults.standard;
        
        userDefaults.setValue(command.argument(at: 0) as! String, forKey: "url")
        userDefaults.setValue(command.argument(at: 1) as! Array<Dictionary<String,String>>, forKey: "headers")
        let notifActive = command.argument(at: 5) as! Bool
        userDefaults.setValue(notifActive , forKey: "NotificationActive")
        
        if notifActive {
            userDefaults.setValue(command.argument(at: 2) as! String, forKey: "NotificationTitle")
            userDefaults.setValue(command.argument(at: 3) as! String, forKey: "NotificationContentRunning")
            userDefaults.setValue(command.argument(at: 4) as! String, forKey: "NotificationContentCompleted")
        }
    }
}

extension OSHealthFitness: PlatformProtocol {

    func sendResult(result: String?, error: NSError?, callBackID: String) {
        var pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR)

        if let error = error, !error.localizedDescription.isEmpty {
            let errorCode = error.code
            let errorMessage = error.localizedDescription
            let errorDict = ["code": errorCode, "message": errorMessage] as [String : Any]
            pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: errorDict);
        } else if let result = result {
            pluginResult = result.isEmpty ? CDVPluginResult(status: CDVCommandStatus_OK) : CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
        }

        self.commandDelegate.send(pluginResult, callbackId: callBackID);
    }

}
