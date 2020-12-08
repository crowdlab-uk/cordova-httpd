cordova.define("com.crowdlab.cordova.httpd.CorHttpd", function(require, exports, module) {

  var argscheck = require('cordova/argscheck');

var corhttpd_exports = {};

corhttpd_exports.startServer = function(options, success, error) {
	  var defaults = {
			    'www_root': '',
			    'port': 8081,
			    'localhost_only': false
			  };
	  
	  // Merge optional settings into defaults.
	  for (var key in defaults) {
	    if (typeof options[key] !== 'undefined') {
	      defaults[key] = options[key];
	    }
	  }
			  
  cordova.exec(success, error, "CorHttpd", "startServer", [ defaults ]);
};

corhttpd_exports.stopServer = function(success, error) {
	  cordova.exec(success, error, "CorHttpd", "stopServer", []);
};

corhttpd_exports.getURL = function(success, error) {
	  cordova.exec(success, error, "CorHttpd", "getURL", []);
};

corhttpd_exports.getLocalPath = function(success, error) {
	  cordova.exec(success, error, "CorHttpd", "getLocalPath", []);
};

module.exports = corhttpd_exports;


});
