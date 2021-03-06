'use strict';

var utils = require('../../collabjs.utils')
  , pool = require('./collabjs.pool.mysql').pool
  , passwordHash = require('password-hash')
  , debug = require('debug')('collabjs:mysql');

/**
 * Creates mentions for the given post.
 * @param {object} connection Database connection.
 * @param {number} postId Post id.
 * @param {string} content Post content.
 * @param {function(object)} callback Callback function.
 */
function addMentions(connection, postId, content, callback) {
  var accounts = utils.parseAccountNames(content, ',');
  if (accounts) {
    connection.query('CALL add_mentions (?,?)', [postId, accounts], function (err) {
      if (err) { debug('addMentions: %j', err); }
      return callback(err);
    });
  }
  callback(false);
}

/**
 * Adds or creates hash tags for the given post.
 * @param {Object} connection Database connection.
 * @param {number} postId Post id.
 * @param {string} content Post content.
 * @param {function(object)} callback Callback function.
 */
function addHashTags(connection, postId, content, callback) {
  var tags = utils.parseHashTags(content, ',');
  if (tags) {
    connection.query('CALL assign_tags (?,?)', [postId, tags], function (err) {
      if (err) { debug('addHashTags: %j', err); }
      return callback(err);
    });
  }
  callback(false);
}

/**
 * Get list of user ids followed by current user.
 * @param {object} connection Database connection.
 * @param {number} userId Current user id.
 * @param {function(Object,Array)} callback Callback function.
 */
// TODO: move evaluation to stored procedure
function getFollowedUsers(connection, userId, callback) {
  var command = "SELECT GROUP_CONCAT(f.targetId separator ',') as list FROM following AS f WHERE f.userId = ?";
  connection.query(command, [userId], function (err, result) {
    if (err) {
      debug('getFollowedUsers: %j', err);
      return callback(err, []);
    }
    var list = result[0].list;
    var ids = [];
    if (list) {
      ids = list.split(',').map(Number);
    }
    callback(false, ids);
  });
}

/**
 * MySQL provider implementation.
 * @constructor
 */
function Provider() {}

Provider.prototype = {
  // TODO: introduce paging support
  getAccounts: function (callback) {
    pool.getConnection(function (err, connection) {
      var command = 'SELECT id, account, name, created, email, system, roles FROM vw_accounts';
      connection.query(command, function (err, result) {
        connection.release();
        if (err) {
          debug('getAccounts: %j', err);
          return callback(err, null);
        }
        callback(err, result);
      });
    });
  },
  getAccountById: function (id, callback) {
    pool.getConnection(function (err, connection) {
      var command = "SELECT * FROM vw_accounts WHERE id = ? LIMIT 1";
      connection.query(command, [id], function (err, result) {
        connection.release();
        if (err) {
          debug('getAccountById: %j', err);
          return callback(err, null);
        }
        if (result.length > 0) {
          var account = result[0];
          account.pictureUrl = utils.getAvatarUrl(account.pictureId);
          return callback(err, account);
        }
        return callback(err, null);
      });
    });
  },
  getAccount: function (account, callback) {
    pool.getConnection(function (err, connection) {
      var command = "SELECT * FROM vw_accounts WHERE account = ? LIMIT 1";
      connection.query(command, [account], function (err, result) {
        connection.release();
        if (err) {
          debug('getAccount: %j', err);
          return callback(err, null);
        }
        if (result.length > 0) {
          var acc = result[0];
          acc.pictureUrl = utils.getAvatarUrl(acc.pictureId);
          return callback(err, acc);
        }
        return callback(err, null);
      });
    });
  },
  createAccount: function (json, callback) {
    pool.getConnection(function (err, connection) {
      json.emailHash = utils.createHash(json.email);
      connection.query('INSERT INTO users SET ?', json, function (err, result) {
        connection.release();
        if (err) {
          debug('createAccount: %j', err);
          var errorMessage = 'Error creating account.';
          if (err.code === 'ER_DUP_ENTRY') {
            errorMessage = 'User with such account already exists.';
          }
          return callback(errorMessage);
        }
        callback(null, { id: result.insertId });
      });
    });
  },
  deleteAccount: function (account, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'DELETE FROM users WHERE account = ? AND system = 0';
      connection.query(command, account, function (err, result) {
        connection.release();
        if (err) {
          debug('deleteAccount: %j', err);
          return callback('Error removing account.');
        }
        callback(null, result.affectedRows > 0);
      });
    });
  },
  updateAccount: function (id, json, callback) {
    var fields = {
      location: json.location || '',                  // update or reset user.location
      website: utils.addHttp(json.website || ''),     // update or reset user.website
      bio: json.bio || ''                             // update or reset user.bio
    };

    // update user.name
    if (json.name && json.name.length > 0) {
      fields.name = json.name;
    }

    pool.getConnection(function (err, connection) {
      connection.query('UPDATE users SET ? WHERE id = ' + connection.escape(id), fields, function (err, result) {
        connection.release();
        if (err) { debug('updateAccount: %j', err); }
        callback(err, result);
      });
    });
  },
  setPassword: function (account, password, callback) {
    if (!account || !password) {
      callback('Error setting account password.');
      return;
    }

    var hash = passwordHash.generate(password)
      , command = 'UPDATE users SET password = ? WHERE account = ?';

    pool.getConnection(function (err, connection) {
      connection.query(command, [hash, account], function (err, result) {
        connection.release();
        if (err) { debug('setPassword: %j', err); }
        var succeeded = (result && result.changedRows > 0);
        callback(err, succeeded);
      });
    });
  },
  // TODO: pass and verify old password before changing
  setAccountPassword: function (userId, password, callback) {
    if (!userId || !password) {
      return callback('Error setting account password.', null);
    }
    this.getAccountById(userId, function (err, result) {
      if (err) {
        debug('setAccountPassword: %j', err);
        return callback(err, result);
      }
      var hashedPassword = passwordHash.generate(password)
        , command = 'UPDATE users SET password = ? WHERE id = ?';
      pool.getConnection(function (err, connection) {
        connection.query(command, [hashedPassword, userId], function (err, result) {
          connection.release();
          if (err) {
            debug('setAccountPassword: %j', err);
            return callback(err, result);
          }
          callback(null, hashedPassword);
        });
      });
    });
  },
  setAccountEmail: function (userId, email, callback) {
    if (!userId || !email) {
      return callback('Error setting account email.', null);
    }
    var command = 'UPDATE users SET email = ?, emailHash = ? WHERE id = ?'
      , hash = utils.createHash(email);
    pool.getConnection(function (err, connection) {
      connection.query(command, [email, hash, userId], function (err, result) {
        connection.release();
        if (err) { debug('setAccountEmail: %j', err); }
        var succeeded = (result && result.changedRows > 0);
        callback(err, succeeded);
      });
    });
  },
  getPublicProfile: function (callerId, targetAccount, callback) {
    pool.getConnection(function (err, connection) {
      getFollowedUsers(connection, callerId, function (err, followed) {
        var command = "SELECT * FROM vw_people WHERE account = ? LIMIT 1";
        connection.query(command, [targetAccount], function (err, result) {
          connection.release();
          if (err || result.length === 0) {
            debug('getPublicProfile: %j', err);
            return callback(err, null);
          }
          var profile = result[0];
          profile.pictureUrl = utils.getAvatarUrl(profile.pictureId);
          profile.isOwnProfile = (profile.id === callerId);
          profile.isFollowed = (followed.indexOf(profile.id) > -1);
          callback(err, profile);
        });
      });
    });
  },
  followAccount: function (callerId, targetAccount, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL follow (?,?)';
      connection.query(command, [callerId, targetAccount], function (err, result) {
        connection.release();
        if (err) { debug('followAccount: %j', err); }
        callback(err, result);
      });
    });
  },
  unfollowAccount: function (callerId, targetAccount, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL unfollow(?,?)';
      connection.query(command, [callerId, targetAccount], function (err, result) {
        connection.release();
        if (err) { debug('unfollowAccount: %j', err); }
        callback(err, result);
      });
    });
  },
  getPeople: function (callerId, topId, callback) {
    pool.getConnection(function (err, connection) {
      getFollowedUsers(connection, callerId, function(err, followed) {
        var command = 'CALL get_people (?)';
        connection.query(command, [topId], function (err, result) {
          connection.release();
          if (err) {
            debug('getPeople: %j', err);
            return callback(err, null);
          }
          var rows = result[0], row;
          // init additional properties
          if (rows.length > 0) {
            for (var i = 0; i < rows.length; i++) {
              row = rows[i];
              row.pictureUrl = utils.getAvatarUrl(row.pictureId);
              row.isOwnProfile = (row.id === callerId);
              row.isFollowed = (followed.indexOf(row.id) > -1);
            }
          }
          callback(err, rows);
        });
      });
    });
  },
  getFollowers: function (callerId, targetId, callback) {
    pool.getConnection(function (err, connection) {
      getFollowedUsers(connection, callerId, function(err, followed) {
        var command = "SELECT u.* FROM following AS f LEFT JOIN vw_users AS u ON u.id = f.userId WHERE f.targetId = ?";
        connection.query(command, [targetId], function (err, result) {
          connection.release();
          if (err) { debug('getFollowers: %j', err); }
          // init additional properties
          if (result.length > 0) {
            var profile;
            for (var i = 0; i < result.length; i++) {
              profile = result[i];
              profile.pictureUrl = utils.getAvatarUrl(profile.pictureId);
              profile.isOwnProfile = (profile.id === callerId);
              profile.isFollowed = (followed.indexOf(profile.id) > -1);
            }
          }
          callback(err, result);
        });
      });
    });
  },
  getFollowing: function (callerId, targetId, callback) {
    pool.getConnection(function (err, connection) {
      getFollowedUsers(connection, callerId, function(err, followed) {
        var command = "SELECT u.* FROM following AS f LEFT JOIN vw_users AS u ON u.id = f.targetId WHERE f.userId = ?";
        connection.query(command, [targetId], function (err, result) {
          connection.release();
          if (err) { debug('getFollowing: %j', err); }
          // init additional properties
          if (result.length > 0) {
            var profile;
            for (var i = 0; i < result.length; i++) {
              profile = result[i];
              profile.pictureUrl = utils.getAvatarUrl(profile.pictureId);
              profile.isOwnProfile = (profile.id === callerId);
              profile.isFollowed = (followed.indexOf(profile.id) > -1);
            }
          }
          callback(err, result);
        });
      });
    });
  },
  getWall: function (userId, topId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL get_wall(?,?)'
        , params = [userId, topId];
      connection.query(command, params, function (err, result) {
        connection.release();
        if (err) {
          debug('getWall: %j', err);
          return callback(err, null);
        }
        var rows = result[0];
        // init additional properties
        if (rows.length > 0) {
          var post;
          for (var i = 0; i < rows.length; i++) {
            post = rows[i];
            post.pictureUrl = utils.getAvatarUrl(post.pictureId);
          }
        }
        callback(err, rows);
      });
    });
  },
  addPost: function (json, callback) {
    pool.getConnection(function (err, connection) {
      var params = [json.userId, json.content, json.created];
      connection.query('CALL add_post (?,?,?)', params, function (err, result) {
        if (err) {
          connection.release();
          debug('addPost: %j', err);
          return callback(err, null);
        }
        var rows = result[0];
        var postId = rows[0].insertId;

        if (postId && postId > 0) {
          // process mentions
          addMentions(connection, postId, json.content, function () {
            // process hashtags
            addHashTags(connection, postId, json.content, function () {
              connection.release();
              callback(err, postId);
            });
          });
        } else {
          connection.release();
          callback(err, false);
        }
      });
    });
  },
  getPost: function (postId, callback) {
    pool.getConnection(function (err, connection) {
      connection.query('SELECT * FROM vw_posts WHERE id = ? LIMIT 1', [postId], function (err, result) {
        connection.release();
        if (err || result.length === 0) {
          debug('getPost: %j', err);
          return callback(err, null);
        }
        var post = result[0];
        post.pictureUrl = utils.getAvatarUrl(post.pictureId);
        callback(err, post);
      });
    });
  },
  getNews: function (userId, topId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL get_news (?, ?)'
        , params = [userId, topId];
      connection.query(command, params, function (err, result) {
        connection.release();
        if (err) {
          debug('getNews: %j', err);
          return callback(err, null);
        }
        var rows = result[0];
        // init additional properties
        if (rows.length > 0) {
          var post;
          for (var i = 0; i < rows.length; i++) {
            post = rows[i];
            post.pictureUrl = utils.getAvatarUrl(post.pictureId);
          }
        }
        callback(err, rows);
      });
    });
  },
  // deletes/mutes News post, this action is individual
  deleteNewsPost: function (userId, postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL delete_news_post (?,?)';
      connection.query(command, [userId, postId], function (err, result) {
        connection.release();
        if (err || !result) {
          debug('deleteNewsPost: %j', err);
          return callback(err, false);
        }
        callback(err, true);
      });
    });
  },
  // deletes post from personal Wall, News and followers' News
  deleteWallPost: function (userId, postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL delete_wall_post (?,?)';
      connection.query(command, [userId, postId], function (err, result) {
        connection.release();
        if (err || !result) {
          debug('deleteWallPost: %j', err);
          return callback(err, false);
        }
        callback(err, true);
      });
    });
  },
  checkNewsUpdates: function (userId, topId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL check_news_updates (?,?)';
      connection.query(command, [userId, topId], function (err, result) {
        connection.release();
        if (err) {
          debug('checkNewsUpdates: %j', err);
          return callback(err, null);
        }
        var row = result[0];
        callback(err, row[0]);
      });
    });
  },
  getNewsUpdates: function (userId, topId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL get_news_updates (?,?)';
      connection.query(command, [userId, topId], function (err, result) {
        connection.release();
        if (err) {
          debug('getNewsUpdates: %j', err);
          return callback(err, null);
        }
        var rows = result[0];
        // init additional properties
        if (rows.length > 0) {
          var post;
          for (var i = 0; i < rows.length; i++) {
            post = rows[i];
            post.pictureUrl = utils.getAvatarUrl(post.pictureId);
          }
        }
        callback(err, rows);
      });
    });
  },
  getPostsByHashTag: function (callerId, hashtag, topId, callback) {
    pool.getConnection(function (err, connection) {
      connection.query('CALL get_posts_by_tag (?,?)', [hashtag, topId], function (err, result) {
        connection.release();
        if (err) {
          debug('getPostsByHashTag: %j', err);
          return callback (err, null);
        }
        var rows = result[0];
        // init additional properties
        if (rows.length > 0) {
          var post;
          for (var i = 0; i < rows.length; i++) {
            post = rows[i];
            post.pictureUrl = utils.getAvatarUrl(post.pictureId);
          }
        }
        callback(err, rows);
      });
    });
  },
  addComment: function (json, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'CALL add_comment (?,?,?,?)'
        , params = [json.userId, json.postId, json.created, json.content];
      connection.query(command, params, function (err, result) {
        connection.release();
        if (err) {
          debug('addComment: %j', err);
          return callback(err, null);
        }
        callback(err, { id: result[0][0].insertId });
      });
    });
  },
  // TODO: review execution plan
  getComments: function (postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'SELECT * FROM vw_comments WHERE postId = ?';
      connection.query(command, [postId], function (err, result) {
        connection.release();
        if (err) {
          debug('getComments: %j', err);
          return callback(err, null);
        }
        // init additional properties
        if (result.length > 0) {
          var comment;
          for (var i = 0; i < result.length; i++) {
            comment = result[i];
            comment.pictureUrl = utils.getAvatarUrl(comment.pictureId);
          }
        }
        callback(err, result);
      });
    });
  },
  lockPost: function (userId, postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'UPDATE posts SET readonly = 1 WHERE userId = ? AND id = ?';
      connection.query(command, [userId, postId], function (err, result) {
        connection.release();
        if (err) { debug('lockPost: %j', err); }
        var succeeded = (result && result.changedRows > 0);
        callback(err, succeeded);
      });
    });
  },
  unlockPost: function (userId, postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'UPDATE posts SET readonly = 0 WHERE userId = ? AND id = ?';
      connection.query(command, [userId, postId], function (err, result) {
        connection.release();
        if (err) { debug('unlockPost: %j', err); }
        var succeeded = (result && result.changedRows > 0);
        callback(err, succeeded);
      });
    });
  },
  addLike: function (userId, postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'INSERT INTO likes (userId, postId) VALUES (?,?)';
      connection.query(command, [userId, postId], function (err/*, result*/) {
        connection.release();
        if (err) { debug('addLike: %j', err); }
        callback(err);
      });
    });
  },
  removeLike: function (userId, postId, callback) {
    pool.getConnection(function (err, connection) {
      var command = 'DELETE FROM likes WHERE userId = ? AND postId = ?';
      connection.query(command, [userId, postId], function (err/*, result*/) {
        connection.release();
        if (err) { debug('removeLike: %j', err); }
        callback(err);
      });
    });
  }
};

module.exports = Provider;