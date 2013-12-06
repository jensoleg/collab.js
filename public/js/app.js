angular.module('collabjs', [
    'ngRoute',
    'ngSanitize',
    'collabjs.services',
    'collabjs.filters',
    'collabjs.directives',
    'collabjs.controllers',
    'angularMoment',
    'infinite-scroll',
    'ui.select2',
    'chieffancypants.loadingBar',
    'ngAnimate'
  ])
  .config(['$routeProvider', 'cfpLoadingBarProvider', function ($routeProvider) {
    'use strict';
    $routeProvider
      .when('/news', { templateUrl: '/partials/news' })
      .when('/people', { templateUrl: '/partials/people' })
      .when('/people/:account', { templateUrl: '/partials/wall' })
      .when('/people/:account/following', { templateUrl: '/partials/following' })
      .when('/people/:account/followers', { templateUrl: '/partials/followers' })
      .when('/mentions', { templateUrl: '/partials/mentions' })
      .when('/posts/:postId', { templateUrl: '/partials/post' })
      .when('/account', { templateUrl: '/partials/account' })
      .when('/account/password', { templateUrl: '/partials/password' })
      .when('/search', { templateUrl: '/partials/search' })
      .when('/help/:article?', { templateUrl: '/partials/help', controller: 'HelpController' })
      .otherwise({ redirectTo: '/news' });
  }]);

angular.module('collabjs.controllers', []);