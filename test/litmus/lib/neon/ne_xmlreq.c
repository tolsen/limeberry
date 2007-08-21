/* 
   XML/HTTP response handling
   Copyright (C) 2004-2005, Joe Orton <joe@manyfish.co.uk>

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
   MA 02111-1307, USA

*/

#include "config.h"

#include "ne_xmlreq.h"
#include "ne_i18n.h"

/* Handle an XML response parse error, setting session error string
 * and closing the connection. */
static int parse_error(ne_session *sess, ne_xml_parser *parser)
{
    ne_set_error(sess, _("Could not parse response: %s"),
                 ne_xml_get_error(parser));
    ne_close_connection(sess);
    return NE_ERROR;
}

int ne_xml_parse_response(ne_request *req, ne_xml_parser *parser)
{
    char buf[8000];
    ssize_t bytes;
    int ret = 0;

    while ((bytes = ne_read_response_block(req, buf, sizeof buf)) > 0) {
        ret = ne_xml_parse(parser, buf, bytes);
        if (ret)
            return parse_error(ne_get_session(req), parser);
    }

    if (bytes == 0) {
        /* Tell the parser that end of document was reached: */
        if (ne_xml_parse(parser, NULL, 0) == 0)
            return NE_OK;
        else
            return parse_error(ne_get_session(req), parser);
    } else {
        return NE_ERROR;
    }    
}

int ne_xml_dispatch_request(ne_request *req, ne_xml_parser *parser)
{
    int ret;

    do {
        ret = ne_begin_request(req);
        if (ret) break;

        if (ne_get_status(req)->klass == 2)
            ret = ne_xml_parse_response(req, parser);
        else
            ret = ne_discard_response(req);
        
        if (ret == NE_OK)
            ret = ne_end_request(req);
    } while (ret == NE_RETRY);

    return ret;
}

