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
dataTypes['SLEEP'] = 'HKCategoryTypeIdentifierSleepAnalysis';
dataTypes['WORKOUTS'] = 'HKWorkoutTypeIdentifier';
dataTypes['BLOOD_GLUCOSE'] = 'HKQuantityTypeIdentifierBloodGlucose';
dataTypes['BLOOD_PRESSURE'] = 'HKCorrelationTypeIdentifierBloodPressure'; // when requesting auth it's HKQuantityTypeIdentifierBloodPressureSystolic and HKQuantityTypeIdentifierBloodPressureDiastolic

dataTypes['WALKING_SPEED'] = 'HKQuantityTypeIdentifierWalkingSpeed';

dataTypes['MINDFULLNESS'] = 'HKCategoryTypeIdentifierMindfulSession';
dataTypes['STAIRS'] = 'HKQuantityTypeIdentifierFlightsClimbed';
dataTypes['CALORIES_ACTIVE'] = 'HKQuantityTypeIdentifierActiveEnergyBurned';
dataTypes['BMI'] = 'HKQuantityTypeIdentifierBodyMassIndex';
dataTypes['HEART_RATE_RESTING'] = 'HKQuantityTypeIdentifierRestingHeartRate';
dataTypes['HEART_RATE_VARIABILITY'] = 'HKQuantityTypeIdentifierHeartRateVariabilitySDNN';
dataTypes['WAIST_CIRCUMFERENCE'] = 'HKQuantityTypeIdentifierWaistCircumference';
/*
//dataTypes['NUTRITION'] = 'HKCorrelationTypeIdentifierFood';
dataTypes['NUTRITION_CALORIES'] = 'HKQuantityTypeIdentifierDietaryEnergyConsumed';
dataTypes['NUTRITION_FAT_TOTAL'] = 'HKQuantityTypeIdentifierDietaryFatTotal';
dataTypes['NUTRITION_FAT_SATURATED'] = 'HKQuantityTypeIdentifierDietaryFatSaturated';
dataTypes['NUTRITION_FAT_POLYUNSATURATED'] = 'HKQuantityTypeIdentifierDietaryFatPolyunsaturated';
dataTypes['NUTRITION_FAT_MONOUNSATURATED'] = 'HKQuantityTypeIdentifierDietaryFatMonounsaturated';
dataTypes['NUTRITION_CHOLESTEROL'] = 'HKQuantityTypeIdentifierDietaryCholesterol';
dataTypes['NUTRITION_SODIUM'] = 'HKQuantityTypeIdentifierDietarySodium';
dataTypes['NUTRITION_POTASSIUM'] = 'HKQuantityTypeIdentifierDietaryPotassium';
dataTypes['NUTRITION_CARBS_TOTAL'] = 'HKQuantityTypeIdentifierDietaryCarbohydrates';
dataTypes['NUTRITION_DIETARY_FIBER'] = 'HKQuantityTypeIdentifierDietaryFiber';
dataTypes['NUTRITION_SUGAR'] = 'HKQuantityTypeIdentifierDietarySugar';
dataTypes['NUTRITION_PROTEIN'] = 'HKQuantityTypeIdentifierDietaryProtein';
dataTypes['NUTRITION_VITAMIN_A'] = 'HKQuantityTypeIdentifierDietaryVitaminA';
dataTypes['NUTRITION_VITAMIN_C'] = 'HKQuantityTypeIdentifierDietaryVitaminC';
dataTypes['NUTRITION_CALCIUM'] = 'HKQuantityTypeIdentifierDietaryCalcium';
dataTypes['NUTRITION_IRON'] = 'HKQuantityTypeIdentifierDietaryIron';
dataTypes['NUTRITION_WATER'] = 'HKQuantityTypeIdentifierDietaryWater';
dataTypes['NUTRITION_CAFFEINE'] = 'HKQuantityTypeIdentifierDietaryCaffeine';
*/
dataTypes['INSULINE'] = 'HKQuantityTypeIdentifierInsulinDelivery';
dataTypes['APPLE_EXERCISE_TIME'] = 'HKQuantityTypeIdentifierAppleExerciseTime';
dataTypes['BLOOD_PREASURE_SYSTOLIC'] = 'HKQuantityTypeIdentifierBloodPressureSystolic';
dataTypes['BLOOD_PREASURE_DIATOLIC'] = 'HKQuantityTypeIdentifierBloodPressureDiastolic';
dataTypes['RESPIRATORY_RATE'] = 'HKQuantityTypeIdentifierRespiratoryRate';
dataTypes['OXYGEN_STAURATION'] = 'HKQuantityTypeIdentifierOxygenSaturation';
//dataTypes['VO2_MAX'] = 'HKQuantityTypeIdentifierVO2Max';
dataTypes['TEMPERATURE'] = 'HKQuantityTypeIdentifierBodyTemperature';

// for parseable units in HK, see https://developer.apple.com/documentation/healthkit/hkunit/1615733-unitfromstring?language=objc
var units = [];
units['STEPS'] = 'count';
units['DISTANCE'] = 'm';
units['CALORIES_BURNED'] = 'kcal';
units['CALORIES_ACTIVE'] = 'kcal';
units['BASAL_METABOLIC_RATE'] = 'kcal';
units['HEIGHT'] = 'm';
units['WEIGHT'] = 'kg';
units['BMI'] = 'count';
units['STAIRS'] = 'count';
units['HEART_RATE'] = 'count/min';
units['HEART_RATE_RESTING'] = 'count/min';
units['HEART_RATE_VARIABILITY'] = 'ms';
units['BODY_FAT_PERCENTAGE'] = '%';
units['WAIST_CIRCUMFERENCE'] = 'm';
/*
units['NUTRITION'] = ['g', 'ml', 'kcal'];
units['NUTRITION_CALORIES'] = 'kcal';
units['NUTRITION_FAT_TOTAL'] = 'g';
units['NUTRITION_FAT_SATURATED'] = 'g';
units['NUTRITION_FAT_POLYUNSATURATED'] = 'g';
units['NUTRITION_FAT_MONOUNSATURATED'] = 'g';
units['NUTRITION_CHOLESTEROL'] = 'mg';
units['NUTRITION_SODIUM'] = 'mg';
units['NUTRITION_POTASSIUM'] = 'mg';
units['NUTRITION_CARBS_TOTAL'] = 'g';
units['NUTRITION_DIETARY_FIBER'] = 'g';
units['NUTRITION_SUGAR'] = 'g';
units['NUTRITION_PROTEIN'] = 'g';
units['NUTRITION_VITAMIN_A'] = 'mcg';
units['NUTRITION_VITAMIN_C'] = 'mg';
units['NUTRITION_CALCIUM'] = 'mg';
units['NUTRITION_IRON'] = 'mg';
units['NUTRITION_WATER'] = 'ml';
units['NUTRITION_CAFFEINE'] = 'g';
*/
units['WALKING_SPEED'] = 'm/s';
units['BLOOD_GLUCOSE'] = 'mmol/L';
units['INSULINE'] = 'IU';
units['APPLE_EXERCISE_TIME'] = 'min';
units['WORKOUTS'] = 'min';
units['BLOOD_PRESSURE'] = 'mmHg';
units['BLOOD_PRESSURE_SYSTOLIC'] = 'mmHg';
units['BLOOD_PRESSURE_DIASTOLIC'] = 'mmHg';
units['RESPIRATORY_RATE'] = 'count/min';
units['OXYGEN_STAURATION'] = '%';
units['VO2_MAX'] = 'ml/(kg*min)';
units['TEMPERATURE'] = 'degC';

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
* New Functions - 
*/
exports.getMetadata = function (success, error) {
  exec(success, error, 'OSHealthFitness', 'getDeviceInfo', []);
};

exports.setConfigurations = function (url,headers,title,contenRunning,contentComplete,hasNotif) {
  exec(null, null, 'OSHealthFitness', 'setConfigurations', [url,headers,title,contenRunning,contentComplete,hasNotif]);
};
function readDateOfBirth(success, error) {
  exec(success, error, 'OSHealthFitness', 'readDateOfBirth', []);
}

function readGender(success, error) {
  exec(success, error, 'OSHealthFitness', 'readGender', []);
}

function findWorkouts(success, error, params) {
  if (!params) params = {};

  hasValidDates(params)

  exec(success, error, 'OSHealthFitness', 'findWorkouts', [params]);
}
function querySampleType(success, error, params) {
  if (params == null) params = {};

  if (!params.sampleType) error("sampleType is a required parameter for this function!")

  hasValidDates(params)

  exec(success, error, 'OSHealthFitness', 'querySampleType', [params]);
}
function queryCorrelationType(success, error, params) {
  if (params == null) params = {};

  if (!params.correlationType) error("correlationType is a required parameter for this function!")

  hasValidDates(params)

  exec(success, error, 'OSHealthFitness', 'queryCorrelationType', [params]);
}

var rounds = function (object, prop) {
  var val = object[prop];
  if (!matches(val, Date)) return;
  object[prop] = Math.round(val.getTime() / 1000);
};

var matches = function (object, typeOrClass) {
  return (typeof typeOrClass === 'string') ?
    typeof object === typeOrClass : object instanceof typeOrClass;
};
var hasValidDates = function (object) {
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

// converts from grams into another unit
// if the unit is not specified or is not weight, then the original quantity is returned
var convertFromGrams = function (toUnit, q) {
  if (toUnit === 'mcg') return q * 1000000;
  if (toUnit === 'mg') return q * 1000;
  if (toUnit === 'kg') return q / 1000;
  return q;
}

function camalize(str) {
  return str.toLowerCase().replace(/[^a-zA-Z0-9]+(.)/g, function (match, chr) {
    return chr.toUpperCase();
  });
}


// refactors the result of a correlation query into returned type
var prepareCorrelation = function (data, dataType) {
  var res = {
    type: camalize(dataType),
    startDate: new Date(data.startDate),
    endDate: new Date(data.endDate),
    source: data.Source,
    value: data.value
  };
  return res;
};

// queries for a datatype
exports.query = function (success, error, params) {
  let opts = JSON.parse(params)
  var startD = new Date(opts.startDate);
  opts.startDate = startD;
  var endD = new Date(opts.endDate);
  opts.endDate = endD;
  opts.type = opts.dataType;
  if (opts.dataType === 'GENDER') {
    readGender(function (data) {
      var res = [];
      res[0] = {
        type: camalize(opts.dataType),
        startDate: startD,
        endDate: endD,
        value: data,
        source: "Health-Iphone"
      };
      success(res);
    }, error);
  } else if (opts.dataType === 'DATE_OF_BIRTH') {
    readDateOfBirth(function (data) {
      var res = [];
      var date = new Date(data);
      res[0] = {
        type: camalize(opts.dataType),
        startDate: startD,
        endDate: endD,
        source: "Health-Iphone",
        value: { day: date.getDate(), month: date.getMonth() + 1, year: date.getFullYear() }
      };
      success(res);
    }, error);
  } else if (opts.dataType === 'WORKOUTS') {
    // opts is not really used, Telerik's plugin just returns ALL workouts
    findWorkouts(function (data) {
      var result = [];
      for (var i = 0; i < data.length; i++) {
        var res = {};
        res.type = camalize(opts.dataType);
        res.startDate = new Date(data[i].startDate);
        res.endDate = new Date(data[i].endDate);
        // filter the results based on the dates
        if ((res.startDate >= startD) && (res.endDate <= endD)) {
          res.value = data[i].activityType;
          res.unit = 'activityType';
          if (data[i].energy) res.calories = parseInt(data[i].energy);
          if (data[i].distance) res.distance = parseInt(data[i].distance);
          res.source = data[i].Source
          result.push(res);
        }
      }
      success(result);
    }, error, opts);
  } else if (opts.dataType === 'SLEEP') {
    // get sleep analysis also
    opts.sampleType = dataTypes[opts.dataType];
    querySampleType(function (data) {
      var result = [];
      for (var i = 0; i < data.length; i++) {
        var res = {};
        res.type = camalize(opts.dataType);
        res.startDate = new Date(data[i].startDate);
        res.endDate = new Date(data[i].endDate);
        res.source = data[i].Source
        switch (data[i].value) {
          case 0:
            res.value = 'in_bed';
            break;
          case 1:
          default:
            res.value = 'sleep';
            break;
          case 2:
            res.value = 'awake';
            break;
          case 3:
            res.value = 'light_sleep';
            break;
          case 4:
            res.value = 'deep_sleep';
            break;
          case 5:
            res.value = 'rem_sleep';
            break;
        }
        res.unit = 'sleepType';
        result.push(res);
      }
      success(result);
    }, error, opts);
  } else if (opts.dataType === 'BLOOD_PRESSURE') {
    // do the correlation queries
    var result = [];
    var qops = { // query-specific options
      type: camalize(opts.dataType),
      startDate: opts.startDate,
      endDate: opts.endDate,
      correlationType: dataTypes[opts.dataType],
      task: opts.task
    }
    if (units[opts.dataType].constructor.name == "Array") qops.units = units[opts.dataType];
    else qops.units = [units[opts.dataType]];

    queryCorrelationType(function (data) {
      for (var i = 0; i < data.length; i++) {
        result.push(prepareCorrelation(data[i], opts.dataType));
      }
      success(result);
    }, error, qops);
  } else if (dataTypes[opts.dataType]) {
    opts.sampleType = dataTypes[opts.dataType];
    if (units[opts.dataType]) {
      opts.unit = units[opts.dataType];
      if(opts.unit == "%"){
        opts.unit = "percent"
      }
    }
    querySampleType(function (data) {
      var result = [];
      var convertSamples = function (samples) {
        for (var i = 0; i < samples.length; i++) {
          var res = {};
          res.type = camalize(opts.dataType);
          res.startDate = new Date(samples[i].startDate);
          res.endDate = new Date(samples[i].endDate);
          res.value = samples[i].value;
          res.source = samples[i].Source

          if (samples[i].unit) res.unit = samples[i].unit;
          else if (opts.unit) res.unit = opts.unit;
          result.push(res);
        }
      };
      convertSamples(data);
      // if (opts.dataType === 'DISTANCE') { // in the case of the distance, add the cycling distances
        // opts.sampleType = 'HKQuantityTypeIdentifierDistanceCycling';
        //re-assign start and end times (because the plugin modifies them later)
        // opts.startDate = startD;
        // opts.endDate = endD;
        // querySampleType(function (data) {
          // convertSamples(data);
          // success(result);
        // }, error, opts);
      // }
	    // else if (opts.dataType === 'CALORIES_BURNED') { // in the case of the calories, add the basal
        // opts.sampleType = 'HKQuantityTypeIdentifierBasalEnergyBurned';
        // opts.startDate = startD;
        // opts.endDate = endD;
        // querySampleType(function (data) {
          // convertSamples(data);
          // success(result);
        // }, error, opts);
      // }
	   // else
	    success(result);

    }, error, opts); // first call to querySampleType
  } else {
    error('unknown data type ' + opts.dataType);
  }
};
