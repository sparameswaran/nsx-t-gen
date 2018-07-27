#!/usr/bin/env python

# nsx-edge-gen
#
# Copyright (c) 2015-Present Pivotal Software, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

__author__ = 'Sabha Parameswaran'

import base64
import cookielib
import ssl
import requests
import re
import time
from pyquery import PyQuery
from lxml import html, etree
import urllib
import urllib2
from urllib2 import urlopen, Request
from requests.utils import quote

try:
    # Python 3
    from urllib.parse import urlparse
except ImportError:
    # Python 2
    from urlparse import urlparse

requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)

DEBUG = False

def get_context():
    if get_context.context is not None:
        return get_context.context
    else:
        raise Error(resourceType + ' config not loaded!!')

get_context.context = None

def set_context(context):
    get_context.context = context


def create_url_opener():
    cookies = cookielib.LWPCookieJar()
    handlers = [
            urllib2.HTTPHandler(debuglevel=1),
            urllib2.HTTPSHandler(),
            urllib2.HTTPCookieProcessor(cookies)
        ]
    opener = urllib2.build_opener(*handlers)
    return opener

def createBaseAuthToken(user, passwd):
    return base64.b64encode('%s:%s' % (user, passwd))

def lookupSessionNonce(response):
    pq = PyQuery(response)
    vmware_session_nonce = ''
    hidden_entry = pq('input:hidden')
    if hidden_entry.attr('name') == 'vmware-session-nonce' :
        vmware_session_nonce = hidden_entry.attr('value')
    if DEBUG:
        print('vmware-session-nonce: ' + vmware_session_nonce)
    return vmware_session_nonce


def init_vmware_session():
    context = get_context()

    vcenterMobServiceInstanceUrl = '/mob/?moid=ServiceInstance&method=retrieveContent'
    data = None #'vmware-session-nonce': context['vmware-session-nonce']}
    cookies = None
    serviceInstanceGetRespSock = invokeVCenterMob(context, vcenterMobServiceInstanceUrl, 'GET', data, cookies)

    serviceInstanceGetRespInfo = serviceInstanceGetRespSock.info()
    cookies = serviceInstanceGetRespSock.info()['Set-Cookie']
    serviceInstanceGetResp = serviceInstanceGetRespSock.read()

    serviceInstanceGetRespSock.close()

    if DEBUG:
        print('Cookies: ' + cookies)
        print('Info: ' + str(serviceInstanceGetRespInfo))
        print('vCenter MOB response :\n' + str(serviceInstanceGetResp)+ '\n-----\n')

    #if response.status_code != requests.codes.ok:
    #        raise Error('Unable to connect to vcenter, error message: ' + vcenterServiceInstanceResponse.text)

    vmware_session_nonce = lookupSessionNonce(serviceInstanceGetResp)
    context['vmware-session-nonce'] = vmware_session_nonce
    context['vmware-cookies'] = cookies
    return

def remove_nsxt_extension_from_vcenter():

    context = get_context()
    init_vmware_session()

    cookies = context['vmware-cookies']

    data = { 'vmware-session-nonce': context['vmware-session-nonce']}
    data['extensionKey'] = 'com.vmware.nsx.management.nsxt'
    vcenterUnregisterExtensionUrl = '/mob/?moid=ExtensionManager&method=unregisterExtension'

    mobRespSock = invokeVCenterMob(context, vcenterUnregisterExtensionUrl, 'POST', data, cookies)
    mobResp = mobRespSock.read()
    mobRespSock.close()

    if DEBUG:
        print('\n\n Mob Response for url[' + vcenterUnregisterExtensionUrl + ']:\n' + mobResp)

    return

def invokeVCenterMob(vcenter_ctx, url, method, data, cookies):
    vcenterOriginUrl = 'https://' + vcenter_ctx['address']
    vcenterMobUrl = vcenterOriginUrl + url

    urlctx = create_non_verify_sslcontext()
    opener = create_url_opener()
    #data = urllib.urlencode({ 'vmware-session-nonce': context['vmware-session-nonce']})
    if data is not None and method == 'POST':
        req = urllib2.Request(vcenterMobUrl, data=urllib.urlencode(data))#, auth=auth, data=data, verify=False, headers=headers)
    else:
        req = urllib2.Request(vcenterMobUrl)

    base64string = createBaseAuthToken(vcenter_ctx.get('admin_user'), vcenter_ctx.get('admin_passwd'))
    #print('Url: {}'.format(vcenterMobUrl))

    req.add_header('Authorization', "Basic %s" % base64string)
    req.add_header('User-Agent', "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/534.30 (KHTML, like Gecko) Ubuntu/11.04 Chromium/12.0.742.112 Chrome/12.0.742.112 Safari/534.30")
    req.add_header('Accept-Charset', 'ISO-8859-1,utf-8;q=0.7,*;q=0.3')
    req.add_header('Accept-Language', 'en-US,en;q=0.8')
    req.add_header("Accept", "text/html,application/xhtml+xml,application/xml,;q=0.9,*/*;q=0.8")
    # req.add_header('Referer', vcenterMobUrl)
    # req.add_header('Origin', vcenterOriginUrl)
    # req.add_header('Host',  vcenter_ctx['address'])

    if cookies is not None:
        req.add_header("Cookie", cookies)
    req.get_method = lambda: method

    sock = urllib2.urlopen(req, context=urlctx)
    return sock

def escape(html):
    """Returns the given HTML with ampersands, quotes and carets encoded."""
    return mark_safe(force_unicode(html).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&#39;'))

def html_decode(s):
    """
    Returns the ASCII decoded version of the given HTML string. This does
    NOT remove normal HTML tags like <p>.
    """
    htmlCodes = (
            ("'", '&#39;'),
            ('"', '&quot;'),
            ('>', '&gt;'),
            ('<', '&lt;'),
            ('&', '&amp;')
        )
    for code in htmlCodes:
        s = s.replace(code[1], code[0])
    return s

def create_non_verify_sslcontext():
    urlctx = ssl.create_default_context()
    urlctx.check_hostname = False
    urlctx.verify_mode = ssl.CERT_NONE
    return urlctx
