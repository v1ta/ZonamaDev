/**
 * Defines the main states in the application.
 * The states you see here will be anchors '#/' unless specifically configured otherwise.
 *
 */

define(['app', 'services'], function (app) {
  'use strict';

  app.config(['$stateProvider', '$urlRouterProvider', '$httpProvider', function ($stateProvider, $urlRouterProvider, $httpProvider) {

    $httpProvider.interceptors.push('authInterceptor');

    $urlRouterProvider.otherwise("/home");

    $stateProvider

    .state('home', {
        url         : '/home',
        templateUrl : 'views/home.html',
        controller  : 'navController',
        data        : { requireLogin: false },
    })
    .state('connect', {
        url         : '/connect',
        templateUrl : 'views/connect.html',
        controller  : 'connectController',
        data        : { requireLogin: false },
    })
    .state('control', {
        url         : '/control',
        templateUrl : 'views/control.html',
        controller  : 'controlController',
        data        : { requireLogin: true },
    })
    .state('tools', {
        url         : '/tools',
        templateUrl : 'views/tools.html',
        controller  : 'toolsController',
        data        : { requireLogin: false },
    })
    .state('about', {
        url         : '/about',
        templateUrl : 'views/about.html',
        data        : { requireLogin: false },
    })
    .state('login', {
        url         : '/login',
        data        : { requireLogin: true },
        controller  : function($state) {
            $state.go("home");
        }
    })
    .state('logout', {
        url         : '/logout',
        data        : { requireLogin: true },
        controller  : function($state, $rootScope) {
            delete $rootScope.currentUsername;
            delete $rootScope.authToken;
            $state.go("home");
        }
    });
  }]);
});
