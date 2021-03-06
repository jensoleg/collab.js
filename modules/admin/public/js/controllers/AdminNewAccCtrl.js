angular.module('collabjs.controllers')
  .controller('AdminNewAccCtrl', ['$scope', '$location', 'adminService',
    function ($scope, $location, adminService) {
      'use strict';

      $scope.init = function () {
        $scope.error = false;
        $scope.account = '';
        $scope.name = '';
        $scope.email = '';
        $scope.password = '';
        $scope.confirmPassword = '';
      };

      $scope.create = function () {
        adminService
          .createAccount($scope.account, $scope.name, $scope.email, $scope.password)
          .then(
            function () { $location.path('/admin/accounts').replace(); },
            function (err) {
              $scope.err = err;
              $scope.password = '';
              $scope.confirmPassword = '';
            }
          );
      };
    }]);