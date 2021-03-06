#!/bin/env node
// for more details on the command above please refer to the following resource:
// http://stackoverflow.com/questions/15061001/what-do-bin-env-mean-in-node-js
'use strict';

var express = require('express')
  , debug = require('debug')('collabjs:server')
  , favicon = require('serve-favicon')
  , logger = require('morgan')
  , cookieParser = require('cookie-parser')
  , bodyParser = require('body-parser')
  , methodOverride = require('method-override')
  , csrf = require('csurf')
  , compress = require('compression')
  , passport = require('passport')
  , LocalStrategy = require('passport-local').Strategy
  , passwordHash = require('password-hash')
  , config = require('./config')
  , utils = require('./collabjs.utils')
  , runtime = require('./collabjs.runtime')
  , RuntimeEvents = runtime.RuntimeEvents
  , runtimeContext = runtime.RuntimeContext
  , db = require('./data')
  , path = require('path');

// Create server

var app = express();

app.set('port', config.env.port);
app.set('host', config.env.host);

/*
 * Authentication Layer
*/

// Password session setup.
//    To support persistent Login sessions, Passport needs to be able to
//    serialize users into and deserialize users out of the session. Typically
//    this will be as simple as storing the user ID when serializing, and finding
//    the user by ID when deserializing.
passport.serializeUser(function (user, done) {
  done(null, user.id);
});

passport.deserializeUser(function (id, done) {
  db.getAccountById(id, function (err, user) {
    if (err) { debug('deserializeUser: %j', err); }
    done(err, user);
  });
});

// Use the LocalStrategy within Passport.
//    Strategies in passport require a 'verify' function, which accepts
//    credentials (in this case, a username and password), and invokes a callback
//    with a user object. 
passport.use(new LocalStrategy(
  function(username, password, done) {
    // async verification, for effect...
    process.nextTick( function(){
      // Find the user by username. If there is no user with the given
      // username, or the password is not correct, set the user to 'false' to
      // indicate failure and set a flash message. Otherwise, return the 
      // authenticated 'user'.
      db.getAccount(username, function (err, user) {
        if (err) { return done(err); }
        if (!user) { return done(null, false, { message: 'Unknown user ' + username }); }
        if (!passwordHash.verify(password, user.password)) {
          return done(null, false, { message: 'Invalid password' });
        }
        return done(null, user);
      });
    });
  }
));

// Load external modules
require('./modules')(runtimeContext);

// Configuration

app.enable('trust proxy');
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');

// use content compression middleware if enabled
if (config.server.compression) {
  app.use(compress());
}

app.use(logger('dev'));
app.use(express.static(__dirname + '/public', { maxAge: 86400000})); // one day
runtimeContext.emit(RuntimeEvents.initStaticContent, app);

app.use(favicon(path.join(__dirname, config.ui.favicon || '/favicon.ico')));
app.use(cookieParser(config.server.session.secret));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(methodOverride()); // support for 'PUT' and 'DELETE' requests

/*
  Enables database store for sessions
  Warning, causes database hits for EVERY http request
  Might require additional efforts for scaling
  Warning: this mode might be deprecated in future versions
*/
if (config.server.session.databaseStore) {
  debug('Using database sessions');
  var dbSession = require('express-session');
  app.use(dbSession({
    name: 'collab.sid',
    secret: config.server.session.secret,
    cookie: {
      maxAge: config.server.session.duration
    },
    store: new db.SessionStore(),
    saveUninitialized: true,
    resave: true
  }));
}
/*
  Enables encrypted cookie sessions (default)
  Does not require additional efforts when scaling
  Greatly improves overall performance
*/
else {
  debug('Using encrypted cookie sessions');
  var cookieSession = require('client-sessions');
  app.use(cookieSession({
    requestKey: 'session',
    cookieName: 'collab.sid',
    secret: config.server.session.secret,
    duration: config.server.session.duration,
    activeDuration: config.server.session.activeDuration,
    cookie: {
      maxAge: config.server.session.duration,
      httpOnly: true,
      secureProxy: config.server.session.secureProxy
    }
  }));
}


// use CSRF protection middleware if enabled
if (config.server.csrf) {
  app.use(csrf());
}

// Initialize Passport! Also use passport.session() middleware, to support
// persistent Login sessions (recommended).
app.use(passport.initialize());
app.use(passport.session());

// Custom middleware

app.use(utils.commonLocals);
//app.use(utils.detectMobileBrowser);

// Default routes

require('./collabjs.web')(runtimeContext);
require('./collabjs.web.api')(runtimeContext);
require('./collabjs.admin.api')(runtimeContext);

// Notify external modules that their routes need to be initialized
runtimeContext.emit(RuntimeEvents.initWebRoutes, app);

// Error handling

// Since this is the last non-error-handling middleware used,
// we assume 404, as nothing else responded.
app.use(function (req, res, next) {
  res.status(404);

  // respond with html page
  if (req.accepts('html')) {
    res.render('404', {
      title: 'Not found',
      url: req.url
    });
    return;
  }

  // respond with json
  if (req.accepts('json')) {
    res.send({ error: 'Not found' });
    return;
  }

  // default to plain-text
  res.type('text').send('Not found');
});

// error-handling middleware, take the same form
// as regular middleware, however they require an
// arity of 4, aka the signature (err, req, res, next).
// when connect has an error, it will invoke ONLY error-handling
// middleware.

// If we were to next() here any remaining non-error-handling
// middleware would then be executed, or if we next(err) to
// continue passing the error, only error-handling middleware
// would remain being executed, however here
// we simply respond with an error page.

app.use(function(err, req, res, next){
  var env = process.env.NODE_ENV || 'development';
  if (env === 'development') { console.error(err.stack); }
  // we may use properties of the error object
  // here and next(err) appropriately, or if
  // we possibly recovered from the error, simply next().
  res.status(err.status || 500);
  res.render('500', { error: err });
});

app.get('/404', function (req, res, next) {
  // trigger a 404 since no other middleware
  // will match /404 after this one, and we're not
  // responding here
  next();
});

app.get('/403', function (req, res, next) {
  // trigger a 403 error
  var err = new Error('not allowed!');
  err.status = 403;
  next(err);
});

app.get('/500', function(req, res, next){
  // trigger a generic (500) error
  next(new Error('keyboard cat!'));
});

// Server startup

// Notify external modules that application is about to start
runtimeContext.emit(RuntimeEvents.appStart, app);
var server = app.listen(app.get('port'), app.get('host'), function () {
  debug("collab.js server listening on port %d in %s mode", app.get('port'), app.settings.env);
});

