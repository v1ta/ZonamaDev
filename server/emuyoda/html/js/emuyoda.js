/*
 * emuyoda.js - AngularJS Application to interface with YodaAPI on server
 *
 * Author: Lord Kator <lordkator@swgemu.com>
 *
 * Created: Sat Jan 16 07:28:29 EST 2016
 */
var emuYodaApp = angular.module('emuYoda', ['ui.router', 'ngSanitize', 'ui.bootstrap']);

emuYodaApp.factory('configService', function($http) {
    var getConfig = function() {
	return $http.get("/api/config").then(function(response) {
	    return response.data;
	});
    };

    var updateConfig = function(config) {
	return $http.put("/api/config", config).then(function(response) {
	    return response.data;
	});
    };

    return {
	getConfig: getConfig,
	updateConfig: updateConfig
    };
})

emuYodaApp.factory('statusService', function($http) {
    var getStatus = function() {
	return $http.get("/api/status").then(function(response) {
	    return response.data;
	});
    };

    return {
	getStatus: getStatus
    };
})

emuYodaApp.factory('controlService', function($http) {
    var serverCommand = function(cmd) {
	return $http.get("/api/control?command=" + cmd).then(function(response) {
	    return response.data;
	});
    };

    return {
	serverCommand: serverCommand
    };
})

emuYodaApp.factory('accountService', function($http) {
    var getAccount = function() {
	return $http.get("/api/account").then(function(response) {
	    return response.data;
	});
    };

    var addAccount = function(account) {
	return $http.post("/api/account", account).then(function(response) {
	    return response.data;
	});
    };

    return {
	getAccount: getAccount,
	addAccount: addAccount
    };
})

emuYodaApp.config(function($stateProvider, $urlRouterProvider) {
    $urlRouterProvider.otherwise("/home");

    $stateProvider

    .state('home', {
	url         : '/home',
	templateUrl : 'pages/home.html',
	controller  : 'mainController'
    })
    .state('connect', {
	url         : '/connect',
	templateUrl : 'pages/connect.html',
	controller  : 'connectController'
    })
    .state('control', {
	url         : '/control',
	templateUrl : 'pages/control.html',
	controller  : 'controlController'
    })
    .state('about', {
	url         : '/about',
	templateUrl : 'pages/about.html'
    });

});

emuYodaApp.controller('mainController', function($scope, $location, configService, statusService, accountService) {
    $scope.account = {};
    $scope.zones = {};
    $scope.canCreateAdminAccount = false;
    $scope.shouldConfigureZones = false;
    $scope.isActive = function(viewLocation) { return viewLocation === $location.path(); }
    $scope.loadData = function() {
	console.log("loadData");
	configService.getConfig().then(function(data) {
	    console.log("gotConfig");
	    $scope.cfg = data.response.config;
	    $scope.messages = "";
	    if (data.response.error) {
		$scope.messages = "API CALL TO " + data.response.service + " FAILED WITH ERROR: " + data.response.error;
	    }

	    $scope.cfg.emu.ZonesEnabled.forEach( function(zone) {
		$scope.zones[zone] = true;
	    });

	    if($scope.cfg.emu.ZonesEnabled.length > 2) {
		$scope.shouldConfigureZones = false;
	    }
	}).catch(function() {
	    $scope.error = "/api/config call failed";
	});

	statusService.getStatus().then(function(data) {
	    console.log("gotStatus");
	    $scope.server_status = data.response.server_status;

	    if($scope.server_status.num_accounts == 0 && $scope.server_status.account && $scope.server_status.account.admin_level >= 15) {
		$scope.canCreateAdminAccount = true;
		$scope.shouldConfigureZones = false;
	    }

	    if($scope.server_status.num_accounts == 1 && $scope.server_status.account && $scope.server_status.account.admin_level >= 15) {
		if($scope.cfg.emu.ZonesEnabled.length <= 2) {
		    $scope.shouldConfigureZones = true;
		}
	    }
	}).catch(function() {
	    $scope.error = "/api/status call failed";
	});
    }

    $scope.createAdminAccount = function() {
	$scope.canCreateAdminAccount = false;
	$scope.account.admin_level = 15;
	accountService.addAccount({ account: $scope.account }).then(function(data) {
	    if(data.response.status == "OK") {
		alert("Account " + $scope.account.username + " Created!");
	    }
	    $scope.messages = JSON.stringify(data.response);
	    $scope.loadData();
	}).catch(function() {
	    $scope.messages = "account POST failed";
	})
    }

    $scope.enableZones = function() {
	$scope.zones['tutorial'] = true;
	$scope.zones['tatooine'] = true;
	$scope.shouldConfigureZones = false;

	var z = [ ];

	for(zone in $scope.zones) {
	    if($scope.zones[zone]) {
		z.push(zone);
	    }
	}

	configService.updateConfig({ config: { emu: { ZonesEnabled: z } } }).then(function(data) {
	    if(data.response.status == "OK") {
		alert("Zones Updated");
	    }
	    $scope.messages = JSON.stringify(data.response);
	    $scope.loadData();
	}).catch(function() {
	    $scope.messages = "config PUT failed";
	})
    }

    $scope.loadData();
});

emuYodaApp.controller('connectController', function($scope, statusService) {
    statusService.getStatus().then(function(data) {
	console.log("control::gotStatus");
	$scope.server_status = data.response.server_status;
    }).catch(function() {
	$scope.error = "/api/status call failed";
    });
});

emuYodaApp.controller('controlController', function($scope, $timeout, $location, statusService, controlService) {
    $scope.message = "";
    $scope.pendingCmd = "";
    $scope.pendingSend = false;
    $scope.sendText = "";

    $scope.updateStatus = function() {
	statusService.getStatus().then(function(data) {
	    console.log("control::gotStatus");
	    $scope.server_status = data.response.server_status;
	}).catch(function() {
	    $scope.error = "/api/status call failed";
	});
    }

    $scope.serverCommand = function(cmd) {
	if(cmd == "send") {
	    if($scope.pendingSend) {
		$scope.pendingSend = false;
		if($scope.sendText == "") {
		    $scope.message = "<b>Missing text to send</b>";
		    return;
		}
		cmd = cmd + "&arg1=" + $scope.sendText;
	    } else {
		$scope.pendingSend = true;
		return;
	    }
	}

	if($scope.pendingCmd != "") {
	    $scope.message = $scope.message + "<br><b>Waiting for <i>" + $scope.pendingCmd + "</i> command to complete</b>";
	    return;
	}

	$scope.pendingCmd = cmd;
	$scope.message = "Sending cmd " + cmd;

	controlService.serverCommand(cmd).then(function(data) {
	    if (data.response.output) {
		$scope.message = data.response.output;
	    } else {
		$scope.message = "Error:" + data.response.error_description
	    }
	    $scope.pendingCmd = "";
	    $scope.updateStatus();
	}).catch(function() {
	    $scope.error = "/api/control call failed";
	    $scope.pendingCmd = "";
	    $scope.updateStatus();
	});
    }

    if(!$scope.ws) {
	console.log("Connecting to console websocket..");
	$scope.ws = new WebSocket('ws://' + $location.host() + ':' + $location.port() + '/api/console')

	    $scope.ws.onmessage = function (e) {
		// TODO has to be a more AngularJS way to do this...
		var logPre = document.getElementById('logPre')
		    if(logPre) {
			logPre.appendChild(document.createTextNode(e.data + "\n"));
			logPre.scrollTop = logPre.scrollHeight;
		    }

		if ($scope.server_status && !$scope.server_status.server_pid) {
		    $scope.updateStatus();
		}
	    }
	$scope.ws.onopen = function () {
	    $scope.message = "Console Connected";
	    console.log($scope.message);
	}
	$scope.ws.onclose = function () {
	    $scope.message = "Console Closed";
	    console.log($scope.message);
	}
    }

    $scope.updateStatus();
});
