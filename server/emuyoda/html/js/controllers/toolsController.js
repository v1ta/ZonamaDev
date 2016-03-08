define([ "./module" ], function(controllers) {
    "use strict";
    controllers.controller("toolsController", [ "$scope", "$http", "$sce", "yodaApiService", function($scope, $http, $sce, yodaApiService) {
        $scope.referenceContent = "";
        $scope.referenceURI = "";
        $scope.displayReference = function(uri) {
            $scope.referenceURI = $sce.trustAsResourceUrl(uri);
        };
    } ]);
});
