var exec = require('cordova/exec');


var dataTypes = [];
dataTypes['STEPS'] = 'HKQuantityTypeIdentifierStepCount';
dataTypes['DISTANCE'] = 'HKQuantityTypeIdentifierDistanceWalkingRunning'; // and HKQuantityTypeIdentifierDistanceCycling
dataTypes['CALORIES_BURNED'] = 'HKQuantityTypeIdentifierActiveEnergyBurned'; // and HKQuantityTypeIdentifierBasalEnergyBurned
dataTypes['BASAL_METABOLIC_RATE'] = 'HKQuantityTypeIdentifierBasalEnergyBurned';
dataTypes['HEIGHT'] = 'HKQuantityTypeIdentifierHeight';
dataTypes['WEIGHT'] = 'HKQuantityTypeIdentifierBodyMass';
dataTypes['HEART_RATE'] = 'HKQuantityTypeIdentifierHeartRate';
dataTypes['BODY_FAT_PERCENTAGE'] = 'HKQuantityTypeIdentifierBodyFatPercentage';
dataTypes['SLEEP'] = 'HKWorkoutTypeIdentifier'; // and HKCategoryTypeIdentifierSleepAnalysis
dataTypes['WORKOUTS'] = 'HKWorkoutTypeIdentifier';
dataTypes['BLOOD_GLUCOSE'] = 'HKQuantityTypeIdentifierBloodGlucose';
dataTypes['BLOOD_PRESSURE'] = 'HKCorrelationTypeIdentifierBloodPressure'; // when requesting auth it's HKQuantityTypeIdentifierBloodPressureSystolic and HKQuantityTypeIdentifierBloodPressureDiastolic
//SLEEP missing

// for parseable units in HK, see https://developer.apple.com/documentation/healthkit/hkunit/1615733-unitfromstring?language=objc
var units = [];
units['STEPS'] = 'count';
units['DISTANCE'] = 'm';
units['CALORIES_BURNED'] = 'kcal';
units['BASAL_METABOLIC_RATE'] = 'kcal';
units['HEIGHT'] = 'm';
units['WEIGHT'] = 'kg';
units['HEART_RATE'] = 'count/min';
units['BODY_FAT_PERCENTAGE'] = '%';
units['BLOOD_GLUCOSE'] = 'mmol/L';
units['appleExerciseTime'] = 'min';
units['BLOOD_PRESSURE'] = 'mmHg';

exports.requestPermissions = function (success, error, params) {

    const { 
        customPermissions, 
        allVariables, 
        fitnessVariables, 
        healthVariables, 
        profileVariables, 
        summaryVariables 
    } = params;

    var args = [customPermissions, allVariables, fitnessVariables, healthVariables, profileVariables, summaryVariables];

    exec(success, error, 'OSHealthFitness', 'requestPermissions', args);
};

exports.getData = function (success, error, params) {
    exec(success, error, 'OSHealthFitness', 'getData', [params]);
};

exports.updateData = function (success, error) {
    exec(success, error, 'OSHealthFitness', 'updateData');
};

exports.enableBackgroundJob = function (success, error) {
    exec(success, error, 'OSHealthFitness', 'enableBackgroundJob');
};

exports.writeData = function (success, error, variable, value) {
    exec(success, error, 'OSHealthFitness', 'writeData', [variable, value]);
};

exports.getLastRecord = function (success, error, variable) {
    exec(success, error, 'OSHealthFitness', 'getLastRecord', [variable]);
};

exports.setBackgroundJob = function (success, error, params) {
    exec(success, error, 'OSHealthFitness', 'setBackgroundJob', [params]);
};

exports.deleteBackgroundJob = function (success, error, params) {
    exec(success, error, 'OSHealthFitness', 'deleteBackgroundJob', [params]);
};

exports.listBackgroundJobs = function (success, error) {
    exec(success, error, 'OSHealthFitness', 'listBackgroundJobs');
};

exports.updateBackgroundJob = function (success, error, params) {
    exec(success, error, 'OSHealthFitness', 'updateBackgroundJob', [params]);
};

/*
* New Functions
*/
function findWorkouts(success,error,params){
    if (!params) params = {};
    exec(success, error, 'OSHealthFitness', 'findWorkouts', [params]);
}
function querySampleType(success,error,params){
    if (params == null) params = {};
    
    if(!params.sampleType) error("sampleType is a required parameter for this function!")

    hasValidDates(params)

    exec(success, error, 'OSHealthFitness', 'querySampleType', [params]);
}
function queryCorrelationType(success,error,params){
    if (params == null) params = {};
    
    if(!params.correlationType) error("correlationType is a required parameter for this function!")

    hasValidDates(params)

    exec(success, error, 'OSHealthFitness', 'queryCorrelationType', [params]);
}

var rounds = function(object, prop) {
    var val = object[prop];
    if (!matches(val, Date)) return;
    object[prop] = Math.round(val.getTime() / 1000);
  };

var matches = function(object, typeOrClass) {
    return (typeof typeOrClass === 'string') ?
      typeof object === typeOrClass : object instanceof typeOrClass;
};
var hasValidDates = function(object) {
    if (!matches(object.startDate, Date)) {
      throw new TypeError("startDate must be a JavaScript Date Object");
    }
    if (!matches(object.endDate, Date)) {
      throw new TypeError("endDate must be a JavaScript Date Object");
    }
    rounds(object, 'startDate');
    rounds(object, 'endDate');
    return object;
  };
  

  // refactors the result of a correlation query into returned type
  var prepareCorrelation = function (data, dataType) {
    var res = {
      id: data.UUID,
      startDate: new Date(data.startDate),
      endDate: new Date(data.endDate),
      value: {}
    };
    if (data.sourceName) res.sourceName = data.sourceName;
    if (data.sourceBundleId) res.sourceBundleId = data.sourceBundleId;
    if (dataType === 'BLOOD_PRESSURE') {
      res.unit = 'mmHG'
      for (var j = 0; j < data.samples.length; j++) {
        var sample = data.samples[j];
        if (sample.sampleType === 'HKQuantityTypeIdentifierBloodPressureSystolic') res.value.systolic = sample.value;
        if (sample.sampleType === 'HKQuantityTypeIdentifierBloodPressureDiastolic') res.value.diastolic = sample.value;
      }
    }
    return res;
  };
  
// queries for a datatype
exports.query = function (success, error, params) {
  let opts = JSON.parse(params)
  var startD = new Date(opts.startDate);
  opts.startDate = startD;
  var endD = new Date(opts.endDate);
  opts.endDate = endD;
  if (opts.dataType === 'WORKOUTS') {
      // opts is not really used, Telerik's plugin just returns ALL workouts
      findWorkouts(function (data) {
        var result = [];
        for (var i = 0; i < data.length; i++) {
          var res = {};
          res.id = data[i].UUID
          res.startDate = new Date(data[i].startDate);
          res.endDate = new Date(data[i].endDate);
          // filter the results based on the dates
          if ((res.startDate >= opts.startDate) && (res.endDate <= opts.endDate)) {
            res.value = data[i].activityType;
            res.unit = 'activityType';
            if (data[i].energy) res.calories = parseInt(data[i].energy);
            if (data[i].distance) res.distance = parseInt(data[i].distance);
            res.sourceName = data[i].sourceName;
            res.sourceBundleId = data[i].sourceBundleId;
            result.push(res);
          }
        }
        success(result);
      }, error,opts);
    }else if(opts.dataType === 'SLEEP'){
        // get sleep analysis also
        opts.sampleType = 'HKCategoryTypeIdentifierSleepAnalysis';
        querySampleType(opts, function (data) {
          var result = [];
          for (var i = 0; i < data.length; i++) {
            var res = {};
            res.id = data[i].UUID
            res.startDate = new Date(data[i].startDate);
            res.endDate = new Date(data[i].endDate);
            switch(data[i].value) {
              case 0:
                res.value = 'sleep.inBed';
                break;
              case 1:
              default:
                res.value = 'sleep';
                break;
              case 2:
                res.value = 'sleep.awake';
                break;
              case 3:
                res.value = 'sleep.light';
                break;
              case 4:
                res.value = 'sleep.deep';
                break;
              case 5:
                res.value = 'sleep.rem';
                break;
            }
            res.unit = 'activityType';
            res.sourceName = data[i].sourceName;
            res.sourceBundleId = data[i].sourceBundleId;
            result.push(res);
          }
          success(result);
        }, error);
    } else if (opts.dataType === 'BLOOD_PRESSURE') {
      // do the correlation queries
      var result = [];
      var qops = { // query-specific options
        startDate: opts.startDate,
        endDate: opts.endDate,
        correlationType: dataTypes[opts.dataType]
      }
      if (units[opts.dataType].constructor.name == "Array") qops.units = units[opts.dataType];
      else qops.units = [ units[opts.dataType] ];
  
        queryCorrelationType(function (data) {
        for (var i = 0; i < data.length; i++) {
          result.push(prepareCorrelation(data[i], opts.dataType));
        }
        success(result);
      }, error,qops);
    } else if (dataTypes[opts.dataType]) {
      opts.sampleType = dataTypes[opts.dataType];
      if (units[opts.dataType]) {
        opts.unit = units[opts.dataType];
      }
      querySampleType(function (data) {
        var result = [];
        var convertSamples = function (samples) {
          for (var i = 0; i < samples.length; i++) {
            var res = {};
            res.id = samples[i].UUID
            res.startDate = new Date(samples[i].startDate);
            res.endDate = new Date(samples[i].endDate);
            if (opts.dataType === 'blood_glucose') {
              res.value = {
                glucose: samples[i].quantity
              }
              if (samples[i].metadata && samples[i].metadata.HKBloodGlucoseMealTime) {
                if(samples[i].metadata.HKBloodGlucoseMealTime == 1) res.value.meal = 'before_meal'
                else res.value.meal = 'after_meal'
              }
              if (samples[i].metadata && samples[i].metadata.HKMetadataKeyBloodGlucoseMealTime) res.value.meal = samples[i].metadata.HKMetadataKeyBloodGlucoseMealTime; // overwrite HKBloodGlucoseMealTime
              if (samples[i].metadata && samples[i].metadata.HKMetadataKeyBloodGlucoseSleepTime) res.value.sleep = samples[i].metadata.HKMetadataKeyBloodGlucoseSleepTime;
              if (samples[i].metadata && samples[i].metadata.HKMetadataKeyBloodGlucoseSource) res.value.source = samples[i].metadata.HKMetadataKeyBloodGlucoseSource;
            } else if (opts.dataType === 'insulin') {
              res.value = {
                insulin: samples[i].quantity
              }
              if (samples[i].metadata && samples[i].metadata.HKInsulinDeliveryReason) {
                if(samples[i].metadata.HKInsulinDeliveryReason == 1) res.value.reason = 'basal'
                else res.value.reason = 'bolus'
              }
              if (samples[i].metadata && samples[i].metadata.HKMetadataKeyInsulinDeliveryReason) res.value.reason = samples[i].metadata.HKMetadataKeyInsulinDeliveryReason; // overwrite HKInsulinDeliveryReason
            } else {
              res.value = samples[i].quantity;
            }
            if (samples[i].unit) res.unit = samples[i].unit;
            else if (opts.unit) res.unit = opts.unit;
            res.sourceName = samples[i].sourceName;
            res.sourceBundleId = samples[i].sourceBundleId;
            result.push(res);
          }
        };
        convertSamples(data);
        if (opts.dataType === 'DISTANCE') { // in the case of the distance, add the cycling distances
          opts.sampleType = 'HKQuantityTypeIdentifierDistanceCycling';
          // re-assign start and end times (because the plugin modifies them later)
          opts.startDate = startD;
          opts.endDate = endD;
          querySampleType(opts, function (data) {
            convertSamples(data);
            success(result);
          }, error);
        } else if (opts.dataType === 'CALORIES_BURNED') { // in the case of the calories, add the basal
          opts.sampleType = 'HKQuantityTypeIdentifierBasalEnergyBurned';
          opts.startDate = startD;
          opts.endDate = endD;
          querySampleType(opts, function (data) {
            convertSamples(data);
            success(result);
          }, error);
        } else success(result);
      }, error,opts); // first call to querySampleType
    } else {
      error('unknown data type ' + opts.dataType);
    }
  };