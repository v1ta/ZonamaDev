    // create the module and name it
    var emuYodaApp = angular.module('emuYoda', ['ngRoute']);

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

    // configure our routes
    emuYodaApp.config(function($routeProvider) {
	    $routeProvider
		// route for the home page
		.when('/', {
			templateUrl : 'pages/home.html',
			controller  : 'mainController'
		})

		// route for the connect page
		.when('/connect', {
			templateUrl : 'pages/connect.html',
			controller  : 'connectController'
		})

		// route for the connect page
		.when('/control', {
			templateUrl : 'pages/control.html',
			controller  : 'controlController'
		})

		// route for the about page
		.when('/about', {
			templateUrl : 'pages/about.html',
			controller  : 'aboutController'
		});
    });

    // create the controller and inject Angular's $scope
    emuYodaApp.controller('mainController', function($scope, configService, statusService, accountService) {
	$scope.account = {};
	$scope.zones = {};
	$scope.canCreateAdminAccount = false;
	$scope.shouldConfigureZones = false;
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

    emuYodaApp.controller('controlController', function($scope, statusService) {
	statusService.getStatus().then(function(data) {
	    console.log("control::gotStatus");
	    $scope.server_status = data.response.server_status;
	}).catch(function() {
	    $scope.error = "/api/status call failed";
	});
    });
