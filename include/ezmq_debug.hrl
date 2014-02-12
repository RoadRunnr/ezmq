%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-ifdef(debug).

-define(DEBUG(FORMAT, DATA),
        io:format("~w(~B): " ++ (FORMAT), [?MODULE, ?LINE | DATA])).
-define(DEBUG(FORMAT), ?DEBUG(FORMAT, [])).

-else.

-define(DEBUG(_FORMAT, _DATA), (ok)).
-define(DEBUG(_FORMAT), ok).

-endif.
